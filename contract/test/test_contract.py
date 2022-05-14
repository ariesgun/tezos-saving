from unittest import TestCase, skip
import time
import datetime
from pytezos import MichelsonRuntimeError, pytezos, ContractInterface

path_to_michelson_contract = "../src/contract.tz"

class TestContract(TestCase):

  @classmethod
  def setUpClass(cls):
    cls.myContract = ContractInterface.create_from(path_to_michelson_contract)

  def test_deposit_is_correctly_recorded(self):
    # Given
    storage = {
      "admins" : [],
      "req_deposit" : 5000000,
      "total_rounds" : 5,
      "penalty" : 30,
      "rewards": 0,
      "players_deposit" : dict(),
      "players_round" : dict(),
      "players_status" : dict(),
      "round_status_map" : dict(),
      "start_date" : 0,
      "period" : 2,
      "total_deposit" : 0,
      "total_withdrawal" : 0
    }
    sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

    # When
    result = self.myContract.deposit().interpret(storage=storage, amount=5000000, source=sender, now=1)

    # Then
    self.assertEqual(result.storage["total_deposit"], 5000000)
    self.assertEqual(result.storage["players_deposit"], {sender: 5000000})
    self.assertEqual(result.storage["players_round"], {sender: 1})
    self.assertEqual(result.storage["players_status"], {sender: "winning"})
    self.assertEqual(result.storage["round_status_map"], {1: 1})

  def test_deposit_twice_same_round(self):
    with self.assertRaises(MichelsonRuntimeError) as administrator_error:
      # Given
      storage = {
        "admins" : [],
        "req_deposit" : 5000000,
        "total_rounds" : 5,
        "penalty" : 30,
        "rewards": 0,
        "players_deposit" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf" : 5000000},
        "players_round" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf" : 1},
        "players_status" : {},
        "round_status_map" : dict(),
        "start_date" : 0,
        "period" : 5*86400,
        "total_deposit" : 0,
        "total_withdrawal" : 0
      }
      sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

      # When
      self.myContract.deposit().interpret(storage=storage, amount=5000000, source=sender, now=3*86400)

    # Then
    error_message = str(administrator_error.exception.args[-1].strip("\\").strip("'"))
    self.assertEqual("ALREADY_DEPOSITED_THIS_ROUND", error_message)

  def test_deposit_second_round(self):
    # Given
    storage = {
      "admins" : [],
      "req_deposit" : 5000000,
      "total_rounds" : 5,
      "penalty" : 30,
      "rewards": 0,
      "players_deposit" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf" : 5000000},
      "players_round" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf" : 1},
      "players_status" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf" : "waiting"},
      "round_status_map" : {1: 1},
      "start_date" : 0,
      "period" : 3,
      "total_deposit" : 5000000,
      "total_withdrawal" : 0
    }
    sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

    # When
    result = self.myContract.deposit().interpret(storage=storage, amount=5000000, source=sender, now=5*86400)

    # Then
    self.assertEqual(result.storage["total_deposit"], 10000000)
    self.assertEqual(result.storage["players_deposit"], {sender: 10000000})
    self.assertEqual(result.storage["players_round"], {sender: 2})
    self.assertEqual(result.storage["round_status_map"], {1: 1,2: 1})
    self.assertEqual(result.storage["players_status"], {sender: "winning"})


  def test_deposit_fail_if_miss_second_round(self):
    with self.assertRaises(MichelsonRuntimeError) as administrator_error:
      # Given
      storage = {
        "admins" : [],
        "req_deposit" : 5000000,
        "total_rounds" : 5,
        "penalty" : 30,
        "rewards": 0,
        "players_deposit" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf" : 5000000},
        "players_round" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf" : 1},
        "players_status" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf" : "waiting"},
        "round_status_map" : dict(),
        "start_date" : 0,
        "period" : 3,
        "total_deposit" : 5000000,
        "total_withdrawal" : 0
      }
      sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

      # When
      self.myContract.deposit().interpret(storage=storage, amount=5000000, source=sender, now=8*86400)

    # Then
    error_message = str(administrator_error.exception.args[-1].strip("\\").strip("'"))
    self.assertEqual("MISSED_DEPOSIT_DEADLINE", error_message)

  def test_deposit_amount_not_match_required_deposit(self):
    with self.assertRaises(MichelsonRuntimeError) as administrator_error:
      # Given
      storage = {
        "admins" : [],
        "req_deposit" : 10000000,
        "total_rounds" : 5,
        "penalty" : 30,
        "rewards": 0,
        "players_deposit" : dict(),
        "players_round" : dict(),
        "players_status" : dict(),
        "round_status_map" : dict(),
        "start_date" : 0,
        "period" : 0,
        "total_deposit" : 0,
        "total_withdrawal" : 0
      }
      sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

      # When
      self.myContract.deposit().interpret(storage=storage, amount=5000000, source=sender)

    # Then
    error_message = str(administrator_error.exception.args[-1].strip("\\").strip("'"))
    self.assertEqual("NOT_MATCH_REQUIRED_DEPOSIT", error_message)

  def test_early_withdraw_fail_if_player_not_registered(self):
    with self.assertRaises(MichelsonRuntimeError) as administrator_error:
      # Given
      storage = {
        "admins" : [],
        "req_deposit" : 10000000,
        "total_rounds" : 5,
        "penalty" : 30,
        "rewards": 0,
        "players_deposit" : dict(),
        "players_round" : dict(),
        "players_status" : dict(),
        "round_status_map" : dict(),
        "start_date" : 5,
        "period" : 2,
        "total_deposit" : 0,
        "total_withdrawal" : 0
      }
      sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

      # When
      self.myContract.earlyWithdraw().interpret(storage=storage, source=sender, now=10)

    # Then
    error_message = str(administrator_error.exception.args[-1].strip("\\").strip("'"))
    self.assertEqual("NOT_FOUND_ACCOUNT_DEPOSIT", error_message)

  def test_early_withdraw_should_update_records_correctly(self):
    # Given
    storage = {
      "admins" : [],
      "req_deposit" : 10000000,
      "total_rounds" : 5,
      "penalty" : 30,
      "rewards": 0,
      "players_deposit" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf": 5000000},
      "players_round" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf": 1},
      "players_status" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf": "winning"},
      "round_status_map" : dict(),
      "start_date" :5,
      "period" : 2,
      "total_deposit" : 5000000,
      "total_withdrawal" : 0
    }
    sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

    # When
    result = self.myContract.earlyWithdraw().interpret(storage=storage, source=sender, now=6)

    # Then
    self.assertEqual(result.storage["total_deposit"], 5000000)
    self.assertEqual(result.storage["total_withdrawal"], 3500000)
    self.assertEqual(result.storage["players_deposit"], {sender: 0})
    self.assertEqual(result.storage["players_round"], {sender: 1})
    self.assertEqual(result.storage["players_status"], {sender: "quit"})

  def test_deposit_fail_if_not_started(self):
    with self.assertRaises(MichelsonRuntimeError) as administrator_error:
      # Given
      storage = {
        "admins" : [],
        "req_deposit" : 10000000,
        "total_rounds" : 5,
        "penalty" : 30,
        "rewards": 0,
        "players_deposit" : dict(),
        "players_round" : dict(),
        "players_status" : dict(),
        "round_status_map" : dict(),
        "start_date" : 5,
        "period" : 0,
        "total_deposit" : 0,
        "total_withdrawal" : 0
      }
      sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

      # When
      self.myContract.deposit().interpret(storage=storage, amount=5000000, source=sender, now=2)

    # Then
    error_message = str(administrator_error.exception.args[-1].strip("\\").strip("'"))
    self.assertEqual("NOT_STARTED_YET", error_message)

  def test_early_withdraw_fail_if_not_started(self):
    with self.assertRaises(MichelsonRuntimeError) as administrator_error:
      # Given
      storage = {
        "admins" : [],
        "req_deposit" : 10000000,
        "total_rounds" : 5,
        "penalty" : 30,
        "rewards": 0,
        "players_deposit" : dict(),
        "players_round" : dict(),
        "players_status" : dict(),
        "round_status_map" : dict(),
        "start_date" : 5,
        "period" : 0,
        "total_deposit" : 0,
        "total_withdrawal" : 0
      }
      sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

      # When
      self.myContract.earlyWithdraw().interpret(storage=storage, source=sender, now=1)

    # Then
    error_message = str(administrator_error.exception.args[-1].strip("\\").strip("'"))
    self.assertEqual("NOT_STARTED_YET", error_message)

  def test_early_withdraw_fail_if_finished(self):
    with self.assertRaises(MichelsonRuntimeError) as administrator_error:
      # Given
      storage = {
        "admins" : [],
        "req_deposit" : 10000000,
        "total_rounds" : 5,
        "penalty" : 30,
        "rewards": 0,
        "players_deposit" : dict(),
        "players_round" : dict(),
        "players_status" : dict(),
        "round_status_map" : dict(),
        "start_date" : 0,
        "period" : 1,
        "total_deposit" : 0,
        "total_withdrawal" : 0
      }
      sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

      # When
      self.myContract.earlyWithdraw().interpret(storage=storage, source=sender, now=7)

    # Then
    error_message = str(administrator_error.exception.args[-1].strip("\\").strip("'"))
    self.assertEqual("FINISHED_ALREADY", error_message)

  def test_withdraw_fail_if_not_started(self):
    with self.assertRaises(MichelsonRuntimeError) as administrator_error:
      # Given
      storage = {
        "admins" : [],
        "req_deposit" : 10000000,
        "total_rounds" : 5,
        "penalty" : 30,
        "rewards": 0,
        "players_deposit" : dict(),
        "players_round" : dict(),
        "players_status" : dict(),
        "round_status_map" : dict(),
        "start_date" : 1,
        "period" : 0,
        "total_deposit" : 0,
        "total_withdrawal" : 0
      }
      sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

      # When
      self.myContract.withdraw().interpret(storage=storage, source=sender, now=0)

    # Then
    error_message = str(administrator_error.exception.args[-1].strip("\\").strip("'"))
    self.assertEqual("NOT_STARTED_YET", error_message)

  def test_withdraw_fail_if_not_finished(self):
    with self.assertRaises(MichelsonRuntimeError) as administrator_error:
      # Given
      storage = {
        "admins" : [],
        "req_deposit" : 10000000,
        "total_rounds" : 5,
        "penalty" : 30,
        "rewards": 0,
        "players_deposit" : dict(),
        "players_round" : dict(),
        "players_status" : dict(),
        "round_status_map" : dict(),
        "start_date" : 1,
        "period" : 1,
        "total_deposit" : 0,
        "total_withdrawal" : 0
      }
      sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

      # When
      self.myContract.withdraw().interpret(storage=storage, source=sender, now=4)

    # Then
    error_message = str(administrator_error.exception.args[-1].strip("\\").strip("'"))
    self.assertEqual("NOT_FINISHED_YET", error_message)

  def test_withdraw_happy_flow(self):
    # Given
    storage = {
      "admins" : [],
      "req_deposit" : 10000000,
      "total_rounds" : 5,
      "penalty" : 30,
      "rewards": 0,
      "players_deposit" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf": 5000000},
      "players_round" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf": 1},
      "players_status" : {"tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf": "won"},
      "round_status_map" : dict(),
      "start_date" : 0,
      "period" : 1,
      "total_deposit" : 5000000,
      "total_withdrawal" : 0
    }
    sender = "tz1L738ifd66ah69PrmKAZzckvvHnbcSeqjf"

    # When
    start_now = pytezos.now()
    result = self.myContract.withdraw().interpret(storage=storage, source=sender, now=6)

    # Then
    self.assertEqual(result.storage["total_deposit"], 5000000)
    self.assertEqual(result.storage["total_withdrawal"], 15000000)
    self.assertEqual(result.storage["players_deposit"], {sender: 0})
    self.assertEqual(result.storage["players_round"], {sender: 1})
