@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for open IO'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_PREPAY_DELV_SO_OPENIO 
as select from ZI_PREPAY_DELIVERY_SO_OPENIO
{
    key PrepaymentReqNumPrepayment,
    key PrepaymentSO,
    key PrepaymentSOItem,
    key DelvSoSalesDocument,
    key DelvSoSalesDocumentItem,
    @Consumption.filter: {
        mandatory: true,
        hidden: false
    }
    @EndUserText.label: 'Sales Organization'
    SalesOrgFilter,   
    @EndUserText.label: 'Customer'
    SoldToPartyFilter,
    @EndUserText.label: 'Customer Name'
    CustomerNameFilter,
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
    PrepaymentRemainingAmount,
    PrepaymentCtrDwnPaymnt,
    PrepaymentDocumentDate,
    PrepaymentDistributionChannel,
    PrepaymentDivision,
    PrepaymentReqNum,

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
    DelvRemainingAmount,
    DelvDocumentDate,
    DelvDistributionChannel,
    DelvDivision
//    ChangedDateTime,
//    lastchangedby,
//    Status
//    @Semantics.amount.currencyCode: 'DelvSoCurrency'
//    AdjustedAmount
}


