@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Prepayment SO Header & item combined'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_Prepayment_SO_Header_Item
  as select from    ZI_Prepayment_SO_Header
    left outer join ZI_Prepayment_SO_Item as _Z_Item      on ZI_Prepayment_SO_Header.SalesDocument = _Z_Item.SalesDocument

   // left outer join I_BillingDocumentItem as _BillingItem on  _Z_Item.SalesDocument     = _BillingItem.SalesDocument
   //                                                       and _Z_Item.SalesDocumentItem = _BillingItem.SalesDocumentItem

    left outer join ZI_CONSUMPTION_AGGR   as _Z_ItemAgg   on  _Z_ItemAgg.Salesorder     = _Z_Item.SalesDocument
                                                          and _Z_ItemAgg.Salesorderitem = _Z_Item.SalesDocumentItem
    //Added 27/4/2026 SAP-3061: prepayment credit note scenario B
    left outer join ZI_Prepayment_CN_AMT as _Z_CN on _Z_CN.SalesDocument = _Z_Item.SalesDocument
                                                    and _Z_CN.SalesDocumentItem = _Z_Item.SalesDocumentItem 
    //SAP-3061: prepayment credit note scenario A and C                                                                                                 
    left outer join ZI_PREPAY_SO_OPEN_AMT as _Z_Open on _Z_Open.SalesDocument = _Z_Item.SalesDocument
                                                    and _Z_Open.SalesDocumentItem = _Z_Item.SalesDocumentItem                                                       
    left outer join I_Customer            as Customer     on Customer.Customer = ZI_Prepayment_SO_Header.SoldToParty

{
  key ZI_Prepayment_SO_Header.SalesDocument,

  key _Z_Item.SalesDocumentItem,
      ZI_Prepayment_SO_Header.SalesOrganization,
      ZI_Prepayment_SO_Header.SoldToParty,
      Customer.CustomerName                                                                      as SoldToName,
      ZI_Prepayment_SO_Header.PrepaymentScenario,
      ZI_Prepayment_SO_Header.BusinessUnit,
      _Z_Item.PrepaymentReqNumPrepayment,
      _Z_Item.SalesDocumentItemCategory,
      _Z_Item.TransactionCurrency,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
        case when ZI_Prepayment_SO_Header.PrepaymentScenario = 'D1' or ZI_Prepayment_SO_Header.PrepaymentScenario = 'D2'
        then cast(
               case when _Z_Item.PrepayActualNetAmt is null
                         or ltrim(_Z_Item.PrepayActualNetAmt, ' ') = ''
                    then '0'
                    else _Z_Item.PrepayActualNetAmt
               end as abap.dec(15,2)
             )
        else cast(_Z_Item.NetAmount as abap.dec(15,2))
        end as NetAmount,
//      _Z_Item.NetAmount,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      _Z_Item.GrossAmount,

//      @Semantics.amount.currencyCode: 'TransactionCurrency'
//      cast(coalesce(cast(_Z_Item.NetAmount as abap.dec(15,2)), 0) as abap.dec(15,2))
//      - cast(coalesce(cast(_Z_ItemAgg.ConsumedSOAmount as abap.dec(15,2)), 0) as abap.dec(15,2)) as RemainingAmount,
        
        //Added 1/4/2026 SAP-3061: prepayment credit note
//        @Semantics.amount.currencyCode: 'TransactionCurrency'
//      cast(coalesce(cast(_Z_Item.NetAmount as abap.dec(15,2)), 0) as abap.dec(15,2)) - cast(coalesce(cast(_Z_CN.CreditNoteAmount as abap.dec(15,2)), 0) as abap.dec(15,2))
//      - cast(coalesce(cast(_Z_ItemAgg.ConsumedSOAmount as abap.dec(15,2)), 0) as abap.dec(15,2)) as RemainingAmount,

        @Semantics.amount.currencyCode: 'TransactionCurrency'
        case 
            when _Z_Item.ItemBillingBlockReason <> 'Y5' and (ZI_Prepayment_SO_Header.PrepaymentScenario = 'A' or ZI_Prepayment_SO_Header.PrepaymentScenario = 'C' or ZI_Prepayment_SO_Header.PrepaymentScenario = 'D1' or ZI_Prepayment_SO_Header.PrepaymentScenario = 'D2' )
            then //Prepay open amount - consumed amount
                coalesce( cast(  _Z_Open.PrepayAmount as abap.dec(15,2) ), 0 )
              - coalesce( cast( _Z_ItemAgg.ConsumedSOAmount as abap.dec(15,2) ), 0 )
            
            when  _Z_Item.ItemBillingBlockReason <> 'Y5' and ZI_Prepayment_SO_Header.PrepaymentScenario = 'B'
                //SO Net amount - CN amount - consumed amount
            then coalesce( cast( _Z_Item.NetAmount as abap.dec(15,2) ), 0 )
                - coalesce( cast( _Z_CN.CreditNoteAmount as abap.dec(15,2) ), 0 )
              - coalesce( cast( _Z_ItemAgg.ConsumedSOAmount as abap.dec(15,2) ), 0 )
              //Legacy SO
            when _Z_Item.ItemBillingBlockReason = 'Y5'
            then coalesce( cast( _Z_Item.NetAmount as abap.dec(15,2) ), 0 ) - coalesce( cast( _Z_ItemAgg.ConsumedSOAmount as abap.dec(15,2) ), 0 )
             else 
                cast(0 as abap.dec(15,2))
        
        end as RemainingAmount,
        
      _Z_Item.ContractItemDownPaymentStatus,
      _Z_Item.ItemBillingBlockReason,
      _Z_Item.BillingDocument as BillingDocument,
      _Z_Item.InvoiceClearingStatus                                        as InvoiceClearingStatus,
      ZI_Prepayment_SO_Header.DocumentDate as DocumentDate,
      ZI_Prepayment_SO_Header.DistributionChannel,
      _Z_Item.Division
}
