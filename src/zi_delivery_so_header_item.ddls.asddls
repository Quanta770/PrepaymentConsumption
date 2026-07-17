@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Delivery SO Header & item combined'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_Delivery_SO_Header_Item as select from ZI_Delivery_SO_Header
 left outer join ZI_Delivery_SO_Item  as _Z_Item
    on ZI_Delivery_SO_Header.SalesDocument = _Z_Item.SalesDocument
    
    left outer join ZI_CONSUMPTION_AGGR  as _Z_ItemAgg
    on _Z_ItemAgg.Salesorder = _Z_Item.SalesDocument
    and _Z_ItemAgg.Salesorderitem = _Z_Item.SalesDocumentItem
//  left outer join ZI_CONSUMPTION_HISTORY as Consume on Consume.Salesorder = ZI_Delivery_SO_Header.SalesDocument
//                                                  and Consume.Salesorderitem = _Z_Item.SalesDocumentItem
//       
{
  key ZI_Delivery_SO_Header.SalesDocument,
  key _Z_Item.SalesDocumentItem,
  ZI_Delivery_SO_Header.SalesOrganization,
  ZI_Delivery_SO_Header.SoldToParty,
  ZI_Delivery_SO_Header.PrepaymentScenario,
  ZI_Delivery_SO_Header.BusinessUnit,
  ZI_Delivery_SO_Header.YY1_SFSOIOType_SDH,
  _Z_Item.PrepaymentReqNumDelivery,
  _Z_Item.SalesDocumentItemCategory,
  _Z_Item.YY1_SFSOIOType_SDI,
  _Z_Item.DeliveryMonth,
  _Z_Item.TransactionCurrency,
  
   @Semantics.amount.currencyCode: 'TransactionCurrency'
   _Z_Item.NetAmount as NetAmount,
   @Semantics.amount.currencyCode: 'TransactionCurrency'
  _Z_Item.GrossAmount,
  _Z_Item.BillingDocument,
  _Z_Item.BillingDocumentItem,
   
   @Semantics.amount.currencyCode: 'TransactionCurrency'
    cast(coalesce(cast(_Z_Item.NetAmount as abap.dec(15,2)), 0) as abap.dec(15,2))
    - cast(coalesce(cast(_Z_ItemAgg.ConsumedSOAmount as abap.dec(15,2)), 0) as abap.dec(15,2))
   // - cast(coalesce(cast(Consume.Openamount as abap.dec(15,2)), 0) as abap.dec(15,2))
    as RemainingAmount,
    _Z_Item.HasWriteOff,
    ZI_Delivery_SO_Header.DocumentDate as DocumentDate,
    _Z_Item.Division,
    ZI_Delivery_SO_Header.DistributionChannel
} 
