@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FIltered for Delivery SO Header ITem'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_DELIVERY_SO_HDR_ITEM_FLTR as select from ZI_Delivery_SO_Header_Item
 left outer join ZI_DELIVERYSO_BILLED as Bill
 on Bill.SalesDocument = ZI_Delivery_SO_Header_Item.SalesDocument
 and Bill.SalesDocumentItem = ZI_Delivery_SO_Header_Item.SalesDocumentItem
 left outer join I_Customer as Customer
 on ZI_Delivery_SO_Header_Item.SoldToParty = Customer.Customer
{

  key ZI_Delivery_SO_Header_Item.SalesDocument,
  key ZI_Delivery_SO_Header_Item.SalesDocumentItem,
  ZI_Delivery_SO_Header_Item.SalesOrganization,
  ZI_Delivery_SO_Header_Item.SoldToParty,
  Customer.CustomerName  as CustomerName,
  ZI_Delivery_SO_Header_Item.PrepaymentScenario,
  ZI_Delivery_SO_Header_Item.BusinessUnit,
  ZI_Delivery_SO_Header_Item.PrepaymentReqNumDelivery,
  ZI_Delivery_SO_Header_Item.SalesDocumentItemCategory,
  ZI_Delivery_SO_Header_Item.YY1_SFSOIOType_SDH,
  ZI_Delivery_SO_Header_Item.YY1_SFSOIOType_SDI,
  ZI_Delivery_SO_Header_Item.DeliveryMonth,
  ZI_Delivery_SO_Header_Item.TransactionCurrency,
  @Semantics.amount.currencyCode: 'TransactionCurrency'
  ZI_Delivery_SO_Header_Item.NetAmount,
  @Semantics.amount.currencyCode: 'TransactionCurrency'
  ZI_Delivery_SO_Header_Item.GrossAmount,
  @Semantics.amount.currencyCode: 'TransactionCurrency'
  ZI_Delivery_SO_Header_Item.RemainingAmount,
  ZI_Delivery_SO_Header_Item.DocumentDate,
  ZI_Delivery_SO_Header_Item.DistributionChannel,
  ZI_Delivery_SO_Header_Item.Division,
  
  case when ZI_Delivery_SO_Header_Item.PrepaymentReqNumDelivery is initial
  then 'XX'
  else ZI_Delivery_SO_Header_Item.PrepaymentReqNumDelivery end as PrepayReq_trim
} where ZI_Delivery_SO_Header_Item.RemainingAmount > 0 and Bill.BillingDocument is null and ZI_Delivery_SO_Header_Item.HasWriteOff is null;
