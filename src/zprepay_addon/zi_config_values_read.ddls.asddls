@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Read Config Values'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CONFIG_VALUES_READ as select from ZR_CONFIG_VALUE
{
   key UUID,
   key ParameterID,
   key ItemNo,
   Category,
   Value1,
   Value2,
   Value3,
   Item_Created_By,
   Item_Created_At,
   Item_Last_Changed_By,
   Item_Last_Changed_At,
   /* Associations */
   _Applications,
   _Parameters 
}
