@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Collection Invoice for  Credit Note'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_COLLECTIONINV_CR_PAYMT   as select from    ZI_DOCREFID_CRNOTE as Opp
    inner join      ZR_CONFIG_VALUE           as config on  config.Category      = Opp.CompanyCode
                                                        and config.ParameterID = 'CollInvCrdtNote'
                                                        and config.Value3 = Opp.FiscalYear
   
    left outer join ZR_CONFIG_VALUE           as prefix on  prefix.Category    = Opp.CompanyCode
                                                        and prefix.ParameterID = 'CreditNotePfix'
{
  key Opp.CompanyCode,
  key Opp.FiscalYear,

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
                    config.Value1
                  )
             else
                 max( Opp.DocumentReferenceID )
         end as abap.char(20))            as Reference3,

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
  config.Value1,
  prefix.Value1
