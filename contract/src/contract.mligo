
type contract_storage =
  {admins : address list;
   req_deposit : tez;
   total_rounds : int;
   penalty : nat;
   players_deposit : (address, tez) big_map;
   players_round : (address, int) big_map;
   players_status : (address, int) big_map;
   start_date : timestamp;
   started : bool;
   period : timestamp;
   deadlines : timestamp list;
   total_deposit : tez;
   total_withdrawal : tez;
   cur_round : int}

type entrypoints =
  Deposit | EarlyWithdraw | AddRewards | Withdraw | Start
| GetMetadata | Update

let fail_if_deposit_not_match_required
  (storage : contract_storage) : unit =
  if Tezos.amount <> storage.req_deposit
  then failwith "NOT_MATCH_REQUIRED_DEPOSIT"
  else unit

let fail_if_not_started (storage : contract_storage) : unit =
  if storage.started
  then unit
  else failwith "NOT_STARTED_YET"

let fail_if_not_finished (storage : contract_storage) : unit =
  if Tezos.now < storage.start_date
  then failwith "NOT_FINISHED_YET"
  else unit

let fail_if_finished (storage : contract_storage) : unit =
  if Tezos.now >= storage.start_date
  then failwith "FINISHED_ALREADY"
  else unit

let _get_current_round (start_date : timestamp) : int =
  let cur_round = (Tezos.now - start_date) / (5 * 86400) in
  cur_round

let fail_if_deposit_current_round_done
  (storage : contract_storage) : unit =
  let player_round =
    match Big_map.find_opt
            Tezos.sender
            storage.players_round
    with
      Some player_round -> player_round
    | None -> 0 in
  let latest_round = _get_current_round storage.start_date in
  if (player_round > latest_round)
  then failwith "ALREADY_DEPOSITED_THIS_ROUND"
  else unit

let find_player_deposit (storage : contract_storage) : tez =
  match Big_map.find_opt
          Tezos.sender
          storage.players_deposit
  with
    Some deposit -> deposit
  | None -> (failwith "NOT_FOUND_ACCOUNT_DEPOSIT")

let deposit (storage : contract_storage) : contract_storage =
  let _ = fail_if_not_started storage in
  let _ = fail_if_deposit_not_match_required storage in
  let _ = fail_if_deposit_current_round_done storage in
  let cur_player_deposit =
    match Big_map.find_opt
            Tezos.sender
            storage.players_deposit
    with
      Some deposit -> deposit
    | None -> 0mutez in
  let new_deposit : tez = cur_player_deposit + Tezos.amount in
  let new_total_deposit : tez =
    storage.total_deposit + Tezos.amount in
  let new_players_deposit =
    Big_map.add
      (Tezos.sender : address)
      (new_deposit)
      storage.players_deposit in
  let cur_player_round =
    match Big_map.find_opt
            Tezos.sender
            storage.players_round
    with
      Some player_round -> player_round
    | None -> 0 in
  let new_players_round =
    Big_map.update
      (Tezos.sender : address)
      (Some (1 + cur_player_round))
      storage.players_round in
  {storage with
    total_deposit = new_total_deposit;
    players_deposit = new_players_deposit;
    players_round = new_players_round}

let early_withdraw (storage : contract_storage)
: contract_storage =
  let _ = fail_if_not_started storage in
  let _ = fail_if_finished storage in
  let player_deposit = find_player_deposit storage in
  let withdraw_amount : tez =
    (player_deposit * abs ((100n - (storage.penalty : nat)))
     / 100n) in
  let new_players_deposit =
    Big_map.update
      (Tezos.sender : address)
      (Some (0mutez))
      storage.players_deposit in
  let new_withdrawal =
    storage.total_withdrawal + withdraw_amount in
  {storage with
    players_deposit = new_players_deposit;
    total_withdrawal = new_withdrawal}

let withdraw (storage : contract_storage) : contract_storage =
  let _ = fail_if_not_started storage in
  let _ = fail_if_not_finished storage in
  let player_deposit = find_player_deposit storage in
  let withdraw_amount : tez = player_deposit + 10000000mutez in
  let new_players_deposit =
    Big_map.update
      (Tezos.sender : address)
      (Some (0mutez))
      storage.players_deposit in
  let new_withdrawal =
    storage.total_withdrawal + withdraw_amount in
  {storage with
    players_deposit = new_players_deposit;
    total_withdrawal = new_withdrawal}

let start (storage : contract_storage) : contract_storage =
  {storage with
    start_date = Tezos.now; started = true}

let main (param, storage : entrypoints * contract_storage)
: (operation list) * contract_storage =
  match param with
    Deposit _ ->
      let new_storage = deposit (storage) in
      ([] : operation list), new_storage
  | EarlyWithdraw _ ->
      let new_storage = early_withdraw (storage) in
      ([] : operation list), new_storage
  | AddRewards _ -> ([] : operation list), storage
  | Withdraw _ ->
      let new_storage = withdraw (storage) in
      ([] : operation list), new_storage
  | Start _ ->
      let new_storage = start (storage) in
      ([] : operation list), new_storage
  | GetMetadata _ -> ([] : operation list), storage
  | Update _ -> ([] : operation list), storage
