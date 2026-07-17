@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Main view to determine the available number range'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_GET_COLLECTIONINV_MAIN
  as select distinct from ZI_COLLECTIONINV_LATEST as OppKey
    inner join            ZR_CONFIG_VALUE           as config on  config.Value1      = OppKey.CompanyCode
                                                              and config.ParameterID = 'CollectionINV'

    left outer join       ZI_GET_COLLECTION_INV_NUM as Cinv   on  Cinv.CompanyCode = OppKey.CompanyCode
                                                              and Cinv.FiscalYear  = OppKey.FiscalYear
    left outer join       ZR_CONFIG_VALUE           as prefix on  prefix.Category    = OppKey.CompanyCode
                                                              and prefix.ParameterID = 'InvoicePrefix'


{
  key OppKey.CompanyCode,
  key OppKey.FiscalYear,
   case when Cinv.Reference3 is null or Cinv.Reference3 = ''
            or left(Cinv.Reference3,3) <> Cinv.CCPrefix
      then
      //       concat(
      //                concat( '9', left( OppKey.CompanyCode, 2 ) ),
      //                config.Value2
      //              )
                   concat(
                      cast(prefix.Value1 as abap.char(3) ),
                    config.Value2
                  )
      else Cinv.Reference3 end   as Reference3,

      config.Value3            as Ref2Check


}
