// main.ts
import { TezosToolkit } from '@taquito/taquito';
import { InMemorySigner } from '@taquito/signer';

import * as faucet from './faucet.json';
import contractJson from '../contract/out/contract.json';
import { MichelsonMap } from '@taquito/taquito';
import { buf2hex } from '@taquito/utils';

const RPC_URL = "https://rpc.ithacanet.teztnets.xyz";

// Storage
/*

type contract_storage =
{
  admins : address set;
  req_deposit : tez;
  total_rounds : nat;
  penalty : nat;
  rewards : tez;
  players_deposit : (address, tez) big_map;
  players_round : (address, int) big_map;
  players_status : (address, status) big_map;
  round_status_map : (nat, nat) map;
  start_date : timestamp;
  period : int;
  total_deposit : tez;
  total_withdrawal : tez
}
*/

const deploy = async () => {
    try {
        const tezos = new TezosToolkit(RPC_URL);
        tezos.setSignerProvider(InMemorySigner.fromFundraiser(faucet.email, faucet.password, faucet.mnemonic.join(' ')));

        // Initial storage definition
        const admins = [faucet.pkh];
        const required_deposit = 5000000;
        const total_rounds = 4;
        const rewards = 100000000
        /*
        const closeDate = Date.now() + 10;    
        const jackpot = 100;
        const description = "This is an incredible Raffle.";
        const players = [] as any[];
        const soldTickets = new MichelsonMap();
        const raffleIsOpen = true;
        const winningTicketHash = buf2hex(Buffer.from("ec85151eb06e201cebfbb06d43daa1093cb4731285466eeb8ba1e79e7ee3fae3"));
        */

        const initialStorage = {
            "admins": admins,
            "req_deposit": required_deposit,
            "total_rounds": total_rounds,
            "penalty": 30, // 30% for early withdrawal
            "rewards": rewards,
            "start_date": (Math.round(Date.now() / 1000)).toString(),
            "players": [],
            "players_deposit": new MichelsonMap(),
            "players_round": new MichelsonMap(),
            "players_status": new MichelsonMap(),
            "round_status_map": new MichelsonMap(),
            "period": 10,
            "total_deposit": 0,
            "test_date": (Date.now()).toString(),
            "total_withdrawal": 0
        }

        const origination = await tezos.contract.originate({
            code: contractJson,
            storage: initialStorage,
          });
        
          await origination.confirmation();
          const contract = await origination.contract();

          console.log(`Operation Hash: ${origination.hash}`);
          console.log(`Contract Address : ${contract.address}`);

    } catch (err) {
        console.log(err);
    }
}

deploy();