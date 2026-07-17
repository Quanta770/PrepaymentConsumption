@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Additional Key for Prepayment SO'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_PREPAYMENT_DELIVERY_SO_KEY as select from ZI_PREPAYMENT_DELIVERY_SO

{
  key PrepaymentReqNumPrepayment,
  key PrepaymentSO,
  key PrepaymentSOItem,
  key DelvSoSalesDocument,
  key DelvSoSalesDocumentItem,
  SourceType,
  PrepaymentSalesOrg,
  PrepaymentSoldTO,
  PrepaymentSoldTOName,
  PrepaymentScenarioPY,
  PrepayBusinessUnit,
  PrepaymentSDItemCtgy,
  PrepaymentCurrency,

  PrepaymentBillingDoc,
  @Semantics.amount.currencyCode: 'PrepaymentCurrency'
  PrepaymentNetAmount,
  @Semantics.amount.currencyCode: 'PrepaymentCurrency'
  PrepaymentGrossAmount,
  @Semantics.amount.currencyCode: 'PrepaymentCurrency'
  PrepaymentRemainingAmount,
  PrepaymentCtrDwnPaymnt,
  PrepaymentReqNum,
  PrepaymentDocumentDate,
  DelvSoSalesOrg,
  DelvSoSoldTO,
  DelvSoldToName,
  DelvSoScenario,
  DelvBusinessUnit,
  DelvSoSDItmCtgy,
  IOType,
  DelvDeliveryMonth,
  DelvSoCurrency,
  @Semantics.amount.currencyCode: 'DelvSoCurrency'
  DelvNetAmount,
  @Semantics.amount.currencyCode: 'DelvSoCurrency'
  DelvSoAmount,
  @Semantics.amount.currencyCode: 'DelvSoCurrency'
  DelvRemainingAmount,
  DelvDocumentDate,
  ChangedDateTime,
  lastchangedby,
  Status,
  @Semantics.amount.currencyCode: 'DelvSoCurrency'
  AdjustedAmount
}
