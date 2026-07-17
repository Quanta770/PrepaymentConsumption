@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Testing of Union'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_Prepayment_Union_Testing as 
select from ZI_Prepayment_SO_Header_Item as Prev
  left outer join ZI_Delivery_SO_Header_Item as delv
    on Prev.PrepaymentReqNumPrepayment = delv.PrepaymentReqNumDelivery
  left outer join ZI_Prepayment_Updates as zpre
    on   delv.SalesDocument = zpre.delvsosalesdocument
    and delv.SalesDocumentItem = zpre.delvsosalesdocumentitem
{
  key Prev.PrepaymentReqNumPrepayment  as PrepaymentReqNumPrepayment,
      'PREPAYMENT' as SourceType,
      Prev.SalesDocument                 as PrepaymentSO,
      Prev.SalesDocumentItem             as PrepaymentSOItem,
      Prev.SalesOrganization             as PrepaymentSalesOrg,
      Prev.SoldToParty                   as PrepaymentSoldTO,
      Prev.PrepaymentScenario            as PrepaymentScenarioPY,
      Prev.SalesDocumentItemCategory     as PrepaymentSDItemCtgy,
      Prev.TransactionCurrency           as PrepaymentCurrency,
      @Semantics.amount.currencyCode: 'PrepaymentCurrency'
      Prev.GrossAmount                   as PrepaymentGrossAmount,
      Prev.ContractItemDownPaymentStatus as PrepaymentCtrDwnPaymnt,
      delv.PrepaymentReqNumDelivery    as PrepaymentReqNum,
      delv.SalesDocument                  as DelvSoSalesDocument,
      delv.SalesDocumentItem              as DelvSoSalesDocumentItem,
      delv.SalesOrganization              as DelvSoSalesOrg,
      delv.SoldToParty                    as DelvSoSoldTO,
      delv.PrepaymentScenario             as DelvSoScenario,
      delv.SalesDocumentItemCategory      as DelvSoSDItmCtgy,
      delv.TransactionCurrency            as DelvSoCurrency,
      @Semantics.amount.currencyCode: 'PrepaymentCurrency'
      delv.GrossAmount                    as DelvSoAmount,
      zpre.changedatetime                 as ChangedDateTime,
      zpre.lastchangedby                       as lastchangedby,
      zpre.status                              as Status

}
where not (
  (Prev.PrepaymentReqNumPrepayment is null or Prev.PrepaymentReqNumPrepayment = '')
  and
  (delv.PrepaymentReqNumDelivery is null or delv.PrepaymentReqNumDelivery = '')
)


union all

select from ZI_Delivery_SO_Header_Item  as delv
left outer join ZI_Prepayment_SO_Header_Item as Prev
on  delv.PrepaymentReqNumDelivery = Prev.PrepaymentReqNumPrepayment
 left outer join ZI_Prepayment_Updates as zpre
    on   delv.SalesDocument = zpre.delvsosalesdocument
    and delv.SalesDocumentItem = zpre.delvsosalesdocumentitem
{
  key Prev.PrepaymentReqNumPrepayment       as PrepaymentReqNumPrepayment,
        'DELIVERY' as SourceType,
      Prev.SalesDocument                 as PrepaymentSO,
      Prev.SalesDocumentItem             as PrepaymentSOItem,
      Prev.SalesOrganization             as PrepaymentSalesOrg,
      Prev.SoldToParty                   as PrepaymentSoldTO,
      Prev.PrepaymentScenario            as PrepaymentScenarioPY,
      Prev.SalesDocumentItemCategory     as PrepaymentSDItemCtgy,
      Prev.TransactionCurrency           as PrepaymentCurrency,
      Prev.GrossAmount                   as PrepaymentGrossAmount,
      Prev.ContractItemDownPaymentStatus as PrepaymentCtrDwnPaymnt,
      delv.PrepaymentReqNumDelivery       as PrepaymentReqNum,
      delv.SalesDocument                  as DelvSoSalesDocument,
      delv.SalesDocumentItem              as DelvSoSalesDocumentItem,
      delv.SalesOrganization              as DelvSoSalesOrg,
      delv.SoldToParty                    as DelvSoSoldTO,
      delv.PrepaymentScenario             as DelvSoScenario,
      delv.SalesDocumentItemCategory      as DelvSoSDItmCtgy,
      delv.TransactionCurrency            as DelvSoCurrency,
      delv.GrossAmount                    as DelvSoAmount,
      zpre.changedatetime                 as ChangedDateTime,
      zpre.lastchangedby                       as lastchangedby,
      zpre.status                              as Status
      

}
where (Prev.PrepaymentReqNumPrepayment is null or Prev.PrepaymentReqNumPrepayment = '')
