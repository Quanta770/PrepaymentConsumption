@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Collection Invoice for Payment Run'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_COLLECTIONINV_PAYMT as select from    ZI_COLLECTIONINV_LATEST as Opp
    inner join      ZR_CONFIG_VALUE           as config on  config.Value1      = Opp.CompanyCode
                                                        and config.ParameterID = 'CollectionINV'
                                                        and config.Category = Opp.FiscalYear
    left outer join ZR_CONFIG_VALUE           as ref2   on  ref2.Category    = Opp.CompanyCode
                                                        and ref2.ParameterID = 'InvoiceRef'
    left outer join ZR_CONFIG_VALUE           as prefix on  prefix.Category    = Opp.CompanyCode
                                                        and prefix.ParameterID = 'InvoicePrefix'
{
  key Opp.CompanyCode,
  key Opp.FiscalYear,
      case when ref2.Category = Opp.CompanyCode
      then
       cast( case
             when max( Opp.DocumentReferenceID ) is null
                  or max( Opp.DocumentReferenceID ) = ''
             then
      //            concat(
      //              concat( '9', left( Opp.CompanyCode, 2 ) ),
      //              config.Value2
      //            )
                       concat(
                      prefix.Value1,
                    config.Value2
                  )


             else
                 max( Opp.DocumentReferenceID )
         end as abap.char(20))
      else
        cast( case
             when max( Opp.DocumentReferenceID ) is null
                  or max( Opp.DocumentReferenceID ) = ''
             then
      //            concat(
      //              concat( '9', left( Opp.CompanyCode, 2 ) ),
      //              config.Value2
      //            )
                             concat(
                      prefix.Value1,
                    config.Value2
                  )
             else
                 max( Opp.DocumentReferenceID )
         end as abap.char(20)) end              as Reference3,

      //concat( '9', left( Opp.CompanyCode, 2 ) )
      prefix.Value1                             as CCPrefix,

      concat( '2', left( Opp.CompanyCode, 2 ) ) as Ref2Check
}
where
      Opp.DocumentReferenceID is not null
  and Opp.DocumentReferenceID != ''
  and Opp.DocumentReferenceID is not initial


group by
  Opp.CompanyCode,
  Opp.FiscalYear,
  config.Value2,
  ref2.Category,
  prefix.Value1
