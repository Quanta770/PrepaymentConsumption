@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Prepayment and Delivery SO combined'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZI_PREPAYMENT_DELIVERY_SO
  as select from    ZI_PREMAYMENT_SO_HDR_ITEM_FLTR as Prev
    left outer join ZI_DELIVERY_SO_HDR_ITEM_FLTR   as delv     // on Prev.PrepaymentReqNumPrepayment = delv.PrepaymentReqNumDelivery
                                                                on Prev.PrepaymentReqNumPrepayment = delv.PrepayReq_trim
    left outer join ZI_Prepayment_Updates        as zpre      on  delv.SalesDocument     = zpre.delvsosalesdocument
                                                              and delv.SalesDocumentItem = zpre.delvsosalesdocumentitem
    left outer join ZI_AMOUNT_TO_ADJUST          as AmtAdjust on Prev.PrepaymentReqNumPrepayment = AmtAdjust.PREPAYMENTREQNUMPREPAYMENT
                                                                and delv.SalesDocument = AmtAdjust.DELVSOSALESDOCUMENT
                                                                and delv.SalesDocumentItem = AmtAdjust.DELVSOSALESDOCUMENTITEM

{
  key Prev.PrepaymentReqNumPrepayment    as PrepaymentReqNumPrepayment,
      'PREPAYMENT'                       as SourceType,
      Prev.SalesDocument                 as PrepaymentSO,
      Prev.SalesDocumentItem             as PrepaymentSOItem,
      Prev.SalesOrganization             as PrepaymentSalesOrg,
      Prev.SoldToParty                   as PrepaymentSoldTO,
      Prev.SoldToName                    as PrepaymentSoldTOName,
      Prev.PrepaymentScenario            as PrepaymentScenarioPY,
      Prev.BusinessUnit                  as PrepayBusinessUnit,
      Prev.SalesDocumentItemCategory     as PrepaymentSDItemCtgy,
      Prev.TransactionCurrency           as PrepaymentCurrency,
      Prev.BillingDocument               as PrepaymentBillingDoc,
            @Semantics.amount.currencyCode: 'PrepaymentCurrency'
      Prev.NetAmount                   as PrepaymentNetAmount,
      @Semantics.amount.currencyCode: 'PrepaymentCurrency'
      Prev.GrossAmount                   as PrepaymentGrossAmount,
      @Semantics.amount.currencyCode: 'PrepaymentCurrency'
      Prev.RemainingAmount               as PrepaymentRemainingAmount,
      Prev.ContractItemDownPaymentStatus as PrepaymentCtrDwnPaymnt,
      Prev.DocumentDate                   as PrepaymentDocumentDate,
      Prev.DistributionChannel as PrepaymentDistributionChannel,
      Prev.Division as PrepaymentDivision,
      delv.PrepaymentReqNumDelivery      as PrepaymentReqNum,
      delv.SalesDocument                 as DelvSoSalesDocument,
      delv.SalesDocumentItem             as DelvSoSalesDocumentItem,
      delv.SalesOrganization             as DelvSoSalesOrg,
      delv.SoldToParty                   as DelvSoSoldTO,
      delv.CustomerName                  as DelvSoldToName,
      delv.PrepaymentScenario            as DelvSoScenario,
      delv.BusinessUnit                  as DelvBusinessUnit,
      delv.SalesDocumentItemCategory     as DelvSoSDItmCtgy,
      delv.YY1_SFSOIOType_SDH            as IOType,
      delv.DeliveryMonth                  as DelvDeliveryMonth,
      delv.TransactionCurrency           as DelvSoCurrency,
      @Semantics.amount.currencyCode: 'PrepaymentCurrency'
      delv.NetAmount                    as DelvNetAmount,
      @Semantics.amount.currencyCode: 'PrepaymentCurrency'
      delv.GrossAmount                   as DelvSoAmount,
      @Semantics.amount.currencyCode: 'PrepaymentCurrency'
      delv.RemainingAmount               as DelvRemainingAmount,
      delv.DocumentDate                   as DelvDocumentDate,
      delv.DistributionChannel as DelvDistributionChannel,
      delv.Division as DelvDivision,
      zpre.changedatetime                as ChangedDateTime,
      zpre.lastchangedby                 as lastchangedby,
      zpre.status                        as Status,
      @Semantics.amount.currencyCode: 'PrepaymentCurrency'
      AmtAdjust.DELVSOAMOUNT_ADJ         as AdjustedAmount
      
      


}
where
         not(
           (
             Prev.PrepaymentReqNumPrepayment    is null
             or Prev.PrepaymentReqNumPrepayment = ''
           )
           and(
                delv.PrepaymentReqNumDelivery   is null
             or delv.PrepaymentReqNumDelivery   = ''
           )
         )


union all

select from       ZI_DELIVERY_SO_HDR_ITEM_FLTR   as delv
  left outer join ZI_PREMAYMENT_SO_HDR_ITEM_FLTR as Prev     // on delv.PrepaymentReqNumDelivery = Prev.PrepaymentReqNumPrepayment
                                                            on delv.PrepaymentReqNumDelivery = Prev.PrepayReq_trim
  left outer join ZI_Prepayment_Updates        as zpre      on  delv.SalesDocument     = zpre.delvsosalesdocument
                                                            and delv.SalesDocumentItem = zpre.delvsosalesdocumentitem
  left outer join ZI_AMOUNT_TO_ADJUST          as AmtAdjust on Prev.PrepaymentReqNumPrepayment = AmtAdjust.PREPAYMENTREQNUMPREPAYMENT
                                                           and delv.SalesDocument = AmtAdjust.DELVSOSALESDOCUMENT
                                                           and delv.SalesDocumentItem = AmtAdjust.DELVSOSALESDOCUMENTITEM
{ 
  key Prev.PrepaymentReqNumPrepayment    as PrepaymentReqNumPrepayment,
      'DELIVERY'                         as SourceType,
      Prev.SalesDocument                 as PrepaymentSO,
      Prev.SalesDocumentItem             as PrepaymentSOItem,
      Prev.SalesOrganization             as PrepaymentSalesOrg,
      Prev.SoldToParty                   as PrepaymentSoldTO,
      Prev.SoldToName                    as PrepaymentSoldTOName,
      Prev.PrepaymentScenario            as PrepaymentScenarioPY,
      Prev.BusinessUnit                  as PrepayBusinessUnit,
      Prev.SalesDocumentItemCategory     as PrepaymentSDItemCtgy,
      Prev.TransactionCurrency           as PrepaymentCurrency,
      Prev.BillingDocument               as PrepaymentBillingDoc,
       Prev.NetAmount                   as PrepaymentNetAmount,
      Prev.GrossAmount                   as PrepaymentGrossAmount,
      Prev.RemainingAmount               as PrepaymentRemainingAmount,
      Prev.ContractItemDownPaymentStatus as PrepaymentCtrDwnPaymnt,
      Prev.DocumentDate                   as PrepaymentDocumentDate,
      Prev.DistributionChannel as PrepaymentDistributionChannel,
      Prev.Division as PrepaymentDivision,
      delv.PrepaymentReqNumDelivery      as PrepaymentReqNum,
      delv.SalesDocument                 as DelvSoSalesDocument,
      delv.SalesDocumentItem             as DelvSoSalesDocumentItem,
      delv.SalesOrganization             as DelvSoSalesOrg,
      delv.SoldToParty                   as DelvSoSoldTO,
      delv.CustomerName                  as DelvSoldToName,
      delv.PrepaymentScenario            as DelvSoScenario,
      delv.BusinessUnit                  as DelvBusinessUnit,
      delv.SalesDocumentItemCategory     as DelvSoSDItmCtgy,
      delv.YY1_SFSOIOType_SDH            as IOType,
      delv.DeliveryMonth                  as DelvDeliveryMonth,
      delv.TransactionCurrency           as DelvSoCurrency,
      delv.NetAmount                    as DelvNetAmount,
      delv.GrossAmount                   as DelvSoAmount,
      delv.RemainingAmount               as DelvRemainingAmount,
      delv.DocumentDate                   as DelvDocumentDate,
      delv.DistributionChannel as DelvDistributionChannel,
      delv.Division as DelvDivision,
      zpre.changedatetime                as ChangedDateTime,
      zpre.lastchangedby                 as lastchangedby,
      zpre.status                        as Status,
      AmtAdjust.DELVSOAMOUNT_ADJ         as AdjustedAmount

}
where
  (
       Prev.PrepaymentReqNumPrepayment is null
    or Prev.PrepaymentReqNumPrepayment = ''
  )
