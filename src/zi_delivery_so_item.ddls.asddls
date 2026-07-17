@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery SO Item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_Delivery_SO_Item 
  as select from I_SalesDocumentItem as DelvSo

    left outer join I_BillingDocumentItem as Billitem
      on Billitem.SalesDocument     = DelvSo.SalesDocument
     and Billitem.SalesDocumentItem = DelvSo.SalesDocumentItem
     and Billitem.CancelledBillingDocument is initial

    left outer join ZI_DELIVERY_SO_ITEM_WRITEOFF as flag
      on flag.SalesOrder     = DelvSo.SalesDocument
     and flag.SalesOrderItem = DelvSo.SalesDocumentItem
   
{
    key DelvSo.SalesDocument,
    key DelvSo.SalesDocumentItem,
    DelvSo.YY1_PrepaymentReqNum_SDI as PrepaymentReqNumDelivery,
    DelvSo.SalesDocumentItemCategory,
    DelvSo.YY1_SFSOIOType_SDI,
    DelvSo.TransactionCurrency,
    DelvSo.YY1_SFSODeliveryMonth_SDI as DeliveryMonth,
    
        @Semantics.amount.currencyCode: 'TransactionCurrency'
    DelvSo.NetAmount as NetAmount,

    
    @Semantics.amount.currencyCode: 'TransactionCurrency'
    cast(
      coalesce(cast(DelvSo.NetAmount as abap.dec(23,2)), 0) + 
      coalesce(cast(DelvSo.TaxAmount as abap.dec(23,2)), 0)
      as abap.curr(23,2)
    ) as GrossAmount,
//    cast(
//        coalesce(cast(case when Curr.Decimals = 0
//      then DelvSo.NetAmount * 100
//      else
//      DelvSo.NetAmount end as abap.dec(23,2)), 0) +
//        coalesce(cast(case when Curr.Decimals = 0
//      then DelvSo.TaxAmount * 100
//      else
//      DelvSo.TaxAmount end as abap.dec(23,2)), 0)
//        as abap.curr(23,2)
//      )                                               as GrossAmount,
    Billitem.BillingDocument as BillingDocument,
    Billitem.BillingDocumentItem as BillingDocumentItem,
    DelvSo.Division,
    
    -- Additional flag for writeoff amount in scenario A (25/11/2025)
    -- This will be NULL if there is no matching writeoff
    flag.HasWriteOff

}

