@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Prepayment SO Item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_Prepayment_SO_Item
  as select from    I_SalesDocumentItem   as SalesItem
    left outer join I_BillingDocumentItem as Billitem on  Billitem.SalesDocument     = SalesItem.SalesDocument
                                                      and Billitem.SalesDocumentItem = SalesItem.SalesDocumentItem
    left outer join I_Currency            as Curr     on Curr.Currency = SalesItem.TransactionCurrency

{
  key SalesItem.SalesDocument,
  key SalesItem.SalesDocumentItem,
      SalesItem.YY1_PrepaymentReqNum_SDI              as PrepaymentReqNumPrepayment,
      SalesItem.SalesDocumentItemCategory,
      SalesItem.TransactionCurrency,

      @Semantics.amount.currencyCode: 'TransactionCurrency'
      SalesItem.NetAmount,
//      case when Curr.Decimals = 0
//      then SalesItem.NetAmount * 100
//      else
//      SalesItem.NetAmount end                         as NetAmount,

      @Semantics.amount.currencyCode: 'TransactionCurrency'
//      cast(
//      coalesce(cast(SalesItem.NetAmount as abap.dec(23,2)), 0) + 
//      coalesce(cast(SalesItem.TaxAmount as abap.dec(23,2)), 0)
//      as abap.curr(23,2)
//    ) as GrossAmount,
      cast(
        coalesce(cast(case when Curr.Decimals = 0
      then SalesItem.NetAmount * 100
      else
      SalesItem.NetAmount end as abap.dec(23,2)), 0) +
        coalesce(cast(case when Curr.Decimals = 0
      then SalesItem.TaxAmount * 100
      else
      SalesItem.TaxAmount end as abap.dec(23,2)), 0)
        as abap.curr(23,2)
      )                                               as GrossAmount,
      
      

      SalesItem.ContractItemDownPaymentStatus,
      SalesItem.ItemBillingBlockReason                as ItemBillingBlockReason,
      Billitem.BillingDocument                        as BillingDocument,
      Billitem.BillingDocumentItem                    as BillingDocumentItem,
      Billitem._BillingDocument.InvoiceClearingStatus as InvoiceClearingStatus,
      SalesItem.Division,
      SalesItem.YY1_PrepayActualNetAmt_SDI as PrepayActualNetAmt,
      SalesItem.YY1_PrepayActualTaxAmt_SDI as PrepayActualTaxAmt,
      SalesItem.YY1_PrepayTaxRate_SDI as PrepayTaxRate
}
