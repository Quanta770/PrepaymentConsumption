@EndUserText.label: 'Input Param for action POSTBILLINGPLAN'
define abstract entity ZA_PARAM_POSTBILLINGPLAN_CHILD
{
  param_currency                : abap.char(3);
  param_amount_to_apply         : abap.char(10);
  param_delv_remaining_amount   : abap.char(10);
  param_prepay_remaining_amount : abap.char(10);
  param_scenario                : abap.char(2);
  param_prepay_so               : abap.char(10);
  param_prepay_so_item          : abap.char(6);
  param_prepay_req_num          : abap.char(10);
  
  _root : association to parent ZA_PARAM_POSTBILLINGPLAN_ROOT;
}
