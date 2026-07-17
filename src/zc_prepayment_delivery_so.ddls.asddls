@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for Prepayment Delivery SO'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZC_PREPAYMENT_DELIVERY_SO as projection on ZI_PREPAYMENT_DELIVERY_SO
{
    key PrepaymentReqNumPrepayment,
    PrepaymentSO,
    PrepaymentSOItem,
    PrepaymentSalesOrg,
    PrepaymentSoldTO,
    PrepaymentScenarioPY,
    PrepayBusinessUnit,
    PrepaymentSDItemCtgy,
    PrepaymentCurrency,

    @Semantics.amount.currencyCode: 'PrepaymentCurrency'
    PrepaymentGrossAmount,
    @Semantics.amount.currencyCode: 'PrepaymentCurrency'   
    PrepaymentRemainingAmount,
    PrepaymentCtrDwnPaymnt,
    PrepaymentReqNum,
    DelvSoSalesDocument,
    DelvSoSalesDocumentItem,
    DelvSoSalesOrg,
    DelvSoSoldTO,
    DelvSoScenario,
    DelvBusinessUnit,
    DelvSoSDItmCtgy,
    IOType,
    DelvSoCurrency,
    @Semantics.amount.currencyCode: 'DelvSoCurrency'
    DelvNetAmount,
    @Semantics.amount.currencyCode: 'DelvSoCurrency'
    DelvSoAmount,
    @Semantics.amount.currencyCode: 'DelvSoCurrency'
    DelvRemainingAmount,
    ChangedDateTime,
    lastchangedby,
    Status,
    @Semantics.amount.currencyCode: 'DelvSoCurrency'
    AdjustedAmount
    
}
