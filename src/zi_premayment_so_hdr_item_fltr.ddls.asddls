@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FIltered for Prepayment SO Header ITem'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_PREMAYMENT_SO_HDR_ITEM_FLTR as select from ZI_Prepayment_SO_Header_Item
{
        key SalesDocument,
        key SalesDocumentItem,
        SalesOrganization,
        SoldToParty,
        SoldToName,
        PrepaymentScenario,
        BusinessUnit,
        PrepaymentReqNumPrepayment,
        SalesDocumentItemCategory,
        TransactionCurrency,
        @Semantics.amount.currencyCode: 'TransactionCurrency'
        NetAmount,
        @Semantics.amount.currencyCode: 'TransactionCurrency'
        GrossAmount,
        @Semantics.amount.currencyCode: 'TransactionCurrency'
        RemainingAmount,
        ContractItemDownPaymentStatus,
        BillingDocument,
        InvoiceClearingStatus,
        ItemBillingBlockReason,
        DocumentDate,
        DistributionChannel,
        Division,
        case when PrepaymentReqNumPrepayment is initial
        then 'XX'
        else PrepaymentReqNumPrepayment end as   PrepayReq_trim
} where 
  RemainingAmount > 0 
  and (ContractItemDownPaymentStatus = 'D' or InvoiceClearingStatus = 'C' or ItemBillingBlockReason = 'Y5')

