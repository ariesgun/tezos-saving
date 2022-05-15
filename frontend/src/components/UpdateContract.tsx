import React, { useState, Dispatch, SetStateAction } from "react";
import { TezosToolkit, WalletContract } from "@taquito/taquito";

interface UpdateContractProps {
  contract: WalletContract | any;
  setUserBalance: Dispatch<SetStateAction<any>>;
  Tezos: TezosToolkit;
  userAddress: string;
  setStorage: Dispatch<SetStateAction<number>>;
}

const UpdateContract = ({ contract, setUserBalance, Tezos, userAddress, setStorage }: UpdateContractProps) => {
  const [loadingDeposit, setLoadingDeposit] = useState<boolean>(false);
  const [loadingEarlyWithdrawal, setLoadingEarlyWithdrawal] = useState<boolean>(false);
  const [loadingRefresh, setLoadingRefresh] = useState<boolean>(false);

  const deposit = async() : Promise<void> => {
    setLoadingDeposit(true);
    try {
      const storage: any = await contract.storage();
      const op = await contract.methods.deposit().send({amount: storage.req_deposit.toNumber() / 1000000});
      await op.confirmation();
      const newStorage: any = await contract.storage();
      if (newStorage) setStorage(newStorage);
      setUserBalance(await Tezos.tz.getBalance(userAddress));
    } catch (error) {
      console.log(error);
    } finally {
      setLoadingDeposit(false);
    }
  }

  const early_withdraw = async() : Promise<void> => {
    setLoadingEarlyWithdrawal(true);
    try {
      const op = await contract.methods.earlyWithdraw().send();
      await op.confirmation();
      const newStorage: any = await contract.storage();
      if (newStorage) setStorage(newStorage);
      setUserBalance(await Tezos.tz.getBalance(userAddress));
    } catch (error) {
      console.log(error);
    } finally {
      setLoadingEarlyWithdrawal(false);
    }
  }

  const refresh = async() : Promise<void> => {
    setLoadingRefresh(true);
    try {
      const op = await contract.methods.update().send();
      await op.confirmation();
      const newStorage: any = await contract.storage();
      if (newStorage) setStorage(newStorage);
      setUserBalance(await Tezos.tz.getBalance(userAddress));
    } catch (error) {
      console.log(error);
    } finally {
      setLoadingRefresh(false);
    }
  }


  if (!contract && !userAddress) return <div>&nbsp;</div>;
  return (
    <div className="buttons">
      <button className="button" disabled={loadingDeposit} onClick={deposit}>
        {loadingDeposit ? (
          <span>
            <i className="fas fa-spinner fa-spin"></i>&nbsp; Please wait
          </span>
        ) : (
          <span>
            <i className="fas fa-plus"></i>&nbsp; Deposit Tezos
          </span>
        )}
      </button>
      <button className="button" disabled={loadingEarlyWithdrawal} onClick={early_withdraw}>
        {loadingEarlyWithdrawal ? (
          <span>
            <i className="fas fa-spinner fa-spin"></i>&nbsp; Please wait
          </span>
        ) : (
          <span>
            <i className="fas fa-minus"></i>&nbsp; Early Withdraw
          </span>
        )}
      </button>
      <button className="button" disabled={loadingRefresh} onClick={refresh}>
        {loadingRefresh ? (
          <span>
            <i className="fas fa-spinner fa-spin"></i>&nbsp; Please wait
          </span>
        ) : (
          <span>
            <i className="fas fa-minus"></i>&nbsp; Refresh Status
          </span>
        )}
      </button>
    </div>
  );
};

export default UpdateContract;
