@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption view for Prepay Status update'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZC_PREPAY_STATUS_UPDATE as projection on  ZI_PREPAY_STATUS_UPDATE

{
    key SapUuid,
    PrepaySalesorder,
    PrepaySalesorderitem,
    DelvSalesorder,
    DelvSalesorderitem,
    Billingplanitem,
    Socurrency,
    @Semantics.amount.currencyCode: 'socurrency'
    Appliedamount,
    AccountingDocument,
    FiscalYear,
    CompanyCode,
    Scenario,
    IOType,
    Isjeposted,
    Isbillingplanposted,
    Isconsumptiontableupdated,
    ReversalFlag,
    WriteoffFlag,
    Message,
    Changedatetime,
    Lastchangedby
}
