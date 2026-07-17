
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_DELIVSO_TO_PREPAYSO as select from ZI_DELIVSO_TO_PREPAYSO
{
    @EndUserText.label: 'Delivery SO'
    key DeliverySO,
    @EndUserText.label: 'Delivery SO Item'
    key DeliverySOItem,
    @EndUserText.label: 'Prepayment SO'
    PrepaySo,
    @EndUserText.label: 'Prepayment SO Item'
    PrepaySOItem,
    @EndUserText.label: 'Accounting Document'
    AccountingDocument,
    @EndUserText.label: 'Prepayment Billing Document'
    PrepayBillingDocument,
    @EndUserText.label: 'Fiscal Year'
    FiscalYear,
    @EndUserText.label: 'Billing Document'
    BillingDocument,
    @EndUserText.label: 'Einv Code'
    EinvCode,
    @EndUserText.label: 'Reference3'
    Reference3IDByBusinessPartner,
    @EndUserText.label: 'Collection Invoice Number'
    CollectionInvoiceNumber,
    @EndUserText.label: 'Consumed Amount'
    ConsumedAmount
}
