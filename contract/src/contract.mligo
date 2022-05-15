type status = Waiting | Winning | Failed | Won | Quit

type contract_storage =
  {admins : address set;
   req_deposit : tez;
   total_rounds : nat;
   penalty : nat;
   rewards : tez;
   start_date : timestamp;
   players : (address) set;
   players_deposit : (address, tez) big_map;
   players_round : (address, int) big_map;
   players_status : (address, status) big_map;
   round_status_map : (nat, nat) map;
   period : int;
   total_deposit : tez;
   test_date : int;
   total_withdrawal : tez}

type entrypoints =
  Deposit | EarlyWithdraw | AddRewards | Withdraw
| GetMetadata of timestamp | Update

let rec count_timestamp
  (t, round, period : timestamp * nat * int) : timestamp =
  if round = 0n
  then t + period
  else
    count_timestamp (t + period, abs (round - 1n), period)

let fail_if_deposit_not_match_required
  (storage : contract_storage) : unit =
  if Tezos.amount <> storage.req_deposit
  then failwith "NOT_MATCH_REQUIRED_DEPOSIT"
  else unit

let fail_if_not_started (storage : contract_storage) : unit =
  if Tezos.now >= storage.start_date
  then unit
  else failwith "NOT_STARTED_YET"

let fail_if_not_finished (storage : contract_storage) : unit =
  let enddate =
    count_timestamp
      (storage.start_date, storage.total_rounds,
       storage.period) in
  if Tezos.now < enddate
  then failwith "NOT_FINISHED_YET"
  else unit

let fail_if_finished (storage : contract_storage) : unit =
  let enddate =
    count_timestamp
      (storage.start_date, storage.total_rounds,
       storage.period) in
  if Tezos.now >= enddate
  then failwith "FINISHED_ALREADY"
  else unit

let _get_current_round
  (start_date, period : timestamp * int) : int =
  let cur_round =
    (Tezos.now - start_date) / (period * 86400) in
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
  let latest_round =
    _get_current_round (storage.start_date, storage.period) in
  if (player_round > latest_round)
  then failwith "ALREADY_DEPOSITED_THIS_ROUND"
  else unit

let fail_if_deposit_miss_previous_round_deadline
  (storage : contract_storage) : unit =
  let current_round =
    _get_current_round (storage.start_date, storage.period) in
  let player_round =
    match Big_map.find_opt
            Tezos.sender
            storage.players_round
    with
      Some player_round -> player_round
    | None -> 0 in
  if ((current_round - player_round) > 0)
  then failwith "MISSED_DEPOSIT_DEADLINE"
  else unit

let find_player_deposit (storage : contract_storage) : tez =
  match Big_map.find_opt
          Tezos.sender
          storage.players_deposit
  with
    Some deposit -> deposit
  | None -> (failwith "NOT_FOUND_ACCOUNT_DEPOSIT")

let _cound_reward_per_player (storage : contract_storage)
: tez =
  let total_winner : nat =
    match Map.find_opt
            (storage.total_rounds)
            storage.round_status_map
    with
      Some count -> count
    | None -> failwith "NO_WINNER_FOUND" in
  (storage.rewards / total_winner)

let deposit (storage : contract_storage) : contract_storage =
  let _ = fail_if_not_started storage in
  let _ = fail_if_deposit_not_match_required storage in
  let _ = fail_if_deposit_current_round_done storage in
  let _ =
    fail_if_deposit_miss_previous_round_deadline storage in
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
  let new_players_status =
    Big_map.update
      (Tezos.sender : address)
      (Some (Winning))
      storage.players_status in
  let cur_round : nat =
    (abs
       (_get_current_round
          (storage.start_date, storage.period))) in
  let cur_round_status_map : nat =
    match Map.find_opt
            (cur_round + 1n)
            storage.round_status_map
    with
      Some count -> count
    | None -> 0n in
  let new_round_status_map =
    Map.update
      (cur_round + 1n)
      (Some (cur_round_status_map + 1n))
      storage.round_status_map in
  let new_players = Set.add Tezos.sender storage.players in
  {storage with
    total_deposit = new_total_deposit;
    players_deposit = new_players_deposit;
    players_round = new_players_round;
    players_status = new_players_status;
    round_status_map = new_round_status_map;
    players = new_players}

let early_withdraw (storage : contract_storage)
: (operation list * contract_storage) =
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
  let new_players_status =
    Big_map.update
      (Tezos.sender : address)
      (Some (Quit))
      storage.players_status in
  let maybe_contract : unit contract option =
    Tezos.get_contract_opt Tezos.sender in
  let receiver : unit contract =
    match maybe_contract with
      Some contract -> contract
    | None -> (failwith ("Not a contract") : unit contract) in
  let payout_operation : operation =
    Tezos.transaction () new_withdrawal receiver in
  ([payout_operation],
   {storage with
     players_deposit = new_players_deposit;
     total_withdrawal = new_withdrawal;
     players_status = new_players_status})

let withdraw (storage : contract_storage)
: (operation list * contract_storage) =
  let _ = fail_if_not_started storage in
  let _ = fail_if_not_finished storage in
  let player_deposit = find_player_deposit storage in
  let reward : tez = _cound_reward_per_player (storage) in
  let withdraw_amount : tez = player_deposit + reward in
  let new_players_deposit =
    Big_map.update
      (Tezos.sender : address)
      (Some (0mutez))
      storage.players_deposit in
  let new_withdrawal =
    storage.total_withdrawal + withdraw_amount in
  let maybe_contract : unit contract option =
    Tezos.get_contract_opt Tezos.sender in
  let receiver : unit contract =
    match maybe_contract with
      Some contract -> contract
    | None -> (failwith ("Not a contract") : unit contract) in
  let payout_operation : operation =
    Tezos.transaction () new_withdrawal receiver in
  ([payout_operation],
   {storage with
     players_deposit = new_players_deposit;
     total_withdrawal = new_withdrawal})

let update (storage : contract_storage) : contract_storage =
  let cur_round =
    _get_current_round (storage.start_date, storage.period) in
  let player_round =
    match Big_map.find_opt
            Tezos.sender
            storage.players_round
    with
      Some player_round -> player_round
    | None -> 0 in
  let stats : status =
    if ((cur_round - player_round) > 0)
    then Waiting
    else Winning in
  let new_players_status =
    Big_map.update
      (Tezos.sender : address)
      (Some (stats))
      storage.players_status in
  {storage with players_status = new_players_status}

let add_rewards (storage : contract_storage)
: contract_storage =
  if Set.mem Tezos.sender storage.admins
  then failwith "NOT_AN_ADMIN"
  else {storage with rewards = Tezos.amount}

let get_metadata (_, storage : timestamp * contract_storage)
: contract_storage =
  if (Tezos.now > storage.start_date)
  then
    {storage with
      test_date = (Tezos.now - storage.start_date)}
  else
    {storage with
      test_date = (storage.start_date - Tezos.now)}

let main (param, storage : entrypoints * contract_storage)
: (operation list) * contract_storage =
  match param with
    Deposit _ ->
      let new_storage = deposit (storage) in
      ([] : operation list), new_storage
  | EarlyWithdraw _ -> early_withdraw (storage)
  | AddRewards _ ->
      let new_storage = add_rewards (storage) in
      ([] : operation list), new_storage
  | Withdraw _ -> withdraw (storage)
  | GetMetadata p ->
      let new_storage = get_metadata (p, storage) in
      ([] : operation list), new_storage
  | Update _ ->
      let new_storage = update (storage) in
      ([] : operation list), new_storage
