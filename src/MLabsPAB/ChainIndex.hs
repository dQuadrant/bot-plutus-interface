{-# LANGUAGE NamedFieldPuns #-}

module MLabsPAB.ChainIndex (handleChainIndexReq) where

import Data.Kind (Type)
import Network.HTTP.Client (defaultManagerSettings, newManager)
import Network.HTTP.Types (Status (statusCode))
import Plutus.ChainIndex.Api (UtxoAtAddressRequest (UtxoAtAddressRequest), UtxoWithCurrencyRequest (UtxoWithCurrencyRequest))
import Plutus.ChainIndex.Client qualified as ChainIndexClient
import Plutus.Contract.Effects (ChainIndexQuery (..), ChainIndexResponse (..))
import Servant.Client (
  BaseUrl (..),
  ClientError (FailureResponse),
  ClientM,
  ResponseF (Response, responseStatusCode),
  Scheme (Http),
  mkClientEnv,
  runClientM,
 )
import Prelude

handleChainIndexReq :: ChainIndexQuery -> IO ChainIndexResponse
handleChainIndexReq = \case
  DatumFromHash datumHash ->
    DatumHashResponse <$> chainIndexQueryOne (ChainIndexClient.getDatum datumHash)
  ValidatorFromHash validatorHash ->
    ValidatorHashResponse <$> chainIndexQueryOne (ChainIndexClient.getValidator validatorHash)
  MintingPolicyFromHash mintingPolicyHash ->
    MintingPolicyHashResponse
      <$> chainIndexQueryOne (ChainIndexClient.getMintingPolicy mintingPolicyHash)
  StakeValidatorFromHash stakeValidatorHash ->
    StakeValidatorHashResponse
      <$> chainIndexQueryOne (ChainIndexClient.getStakeValidator stakeValidatorHash)
  RedeemerFromHash _ ->
    pure $ RedeemerHashResponse Nothing
  -- RedeemerFromHash redeemerHash ->
  --   pure $ RedeemerHashResponse (Maybe Redeemer)
  TxOutFromRef txOutRef ->
    TxOutRefResponse <$> chainIndexQueryOne (ChainIndexClient.getTxOut txOutRef)
  TxFromTxId txId ->
    TxIdResponse <$> chainIndexQueryOne (ChainIndexClient.getTx txId)
  UtxoSetMembership txOutRef ->
    UtxoSetMembershipResponse <$> chainIndexQueryMany (ChainIndexClient.getIsUtxo txOutRef)
  UtxoSetAtAddress page credential ->
    UtxoSetAtResponse
      <$> chainIndexQueryMany
        (ChainIndexClient.getUtxoSetAtAddress (UtxoAtAddressRequest (Just page) credential))
  UtxoSetWithCurrency page assetClass ->
    UtxoSetAtResponse
      <$> chainIndexQueryMany
        (ChainIndexClient.getUtxoSetWithCurrency (UtxoWithCurrencyRequest (Just page) assetClass))
  GetTip ->
    GetTipResponse <$> chainIndexQueryMany ChainIndexClient.getTip

chainIndexQuery' :: forall (a :: Type). ClientM a -> IO (Either ClientError a)
chainIndexQuery' endpoint = do
  manager' <- newManager defaultManagerSettings
  runClientM endpoint $ mkClientEnv manager' $ BaseUrl Http "localhost" 9083 ""

chainIndexQueryMany :: forall (a :: Type). ClientM a -> IO a
chainIndexQueryMany endpoint =
  either (error . show) id <$> chainIndexQuery' endpoint

chainIndexQueryOne :: forall (a :: Type). ClientM a -> IO (Maybe a)
chainIndexQueryOne endpoint = do
  res <- chainIndexQuery' endpoint
  case res of
    Right result -> pure $ Just result
    Left failureResp@(FailureResponse _ Response {responseStatusCode})
      | statusCode responseStatusCode == 404 -> pure Nothing
      | otherwise -> error (show failureResp)
    Left failureResp -> error (show failureResp)