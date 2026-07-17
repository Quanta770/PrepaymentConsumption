@EndUserText.label: 'Input Param for action POSTBILLINGPLAN'
define root abstract entity ZA_PARAM_POSTBILLINGPLAN_ROOT
{
  dummy : abap.char(1);
  _param : composition [0..*] of ZA_PARAM_POSTBILLINGPLAN_CHILD;
}
