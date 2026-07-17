@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Credit Note Mail'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_COLLECTIONINV_CR_MAIN as select distinct from ZI_DOCREFID_CRNOTE as OppKey
    inner join            ZR_CONFIG_VALUE           as config on  config.Category     = OppKey.CompanyCode
                                                              and config.ParameterID = 'CollInvCrdtNote'
                                                              and config.Value3 = OppKey.FiscalYear

    left outer join       ZI_COLLECTIONINV_CR_PAYMT as Cinv   on  Cinv.CompanyCode = OppKey.CompanyCode
                                                              and Cinv.FiscalYear  = OppKey.FiscalYear
    left outer join       ZR_CONFIG_VALUE           as prefix on  prefix.Category    = OppKey.CompanyCode
                                                              and prefix.ParameterID = 'CreditNotePfix'


{
  key OppKey.CompanyCode,
  key OppKey.FiscalYear,
   case when Cinv.Reference3 is null or Cinv.Reference3 = ''
            or left(Cinv.Reference3,2) <> Cinv.CCPrefix or  cast( right( Cinv.Reference3, 8 ) as int4 ) < cast( config.Value1 as int4 )
      then
           concat(
              cast(prefix.Value1 as abap.char(3) ),
            config.Value1
          )
      else Cinv.Reference3 end   as Reference3,

      config.Value2            as Ref2Check


}



