@ClientHandling: {
  type: #CLIENT_DEPENDENT,          // required
  algorithm: #SESSION_VARIABLE      // or #PARAMETER
}
@EndUserText.label: 'View for Amount to Adjust'
define table function ZI_AMOUNT_TO_ADJUST
  //with parameters
  //    ip_prepaynum   : abap.char(10),
  //    ip_salesdoc    : abap.char(10),
  //   ip_salesitem   : abap.char(6),
returns
{
  RCLNT                      : mandt;
  PREPAYMENTREQNUMPREPAYMENT : abap.char(10);
  SOURCETYPE                 : abap.char(10);
  PREPAYMENTSO               : abap.char(10);
  PREPAYMENTSOITEM           : abap.char(6);
  PREPAYMENTSALESORG         : abap.char(4);
  PREPAYMENTSOLDTO           : abap.char(10);
  PREPAYMENTSCENARIOPY       : abap.char(1);
  PREPAYMENTSDITEMCTGY       : abap.char(4);
  PREPAYMENTCURRENCY         : abap.char(3);
  PREPAYMENTNETAMOUNT        : abap.curr(23,2);
  //PREPAYMENTGROSSAMOUNT      : abap.curr(23,2);
  PREPAYMENTREMAININGAMOUNT  : abap.curr(23,2);
  PREPAYMENTCTRDWNPAYMNT     : abap.char(1);
  PREPAYMENTREQNUM           : abap.char(10);
  DELVSOSALESDOCUMENT        : abap.char(10);
  DELVSOSALESDOCUMENTITEM    : abap.char(6);
  DELVSOSALESORG             : abap.char(4);
  DELVSOSOLDTO               : abap.char(10);
  DELVSOSCENARIO             : abap.char(10);
  DELVSOSDITMCTGY            : abap.char(4);
  DELVSOCURRENCY             : abap.cuky;
  DELVSONETAMOUNT            : abap.curr(23,2);
  //DELVSOGROSSAMOUNT          : abap.curr(23,2);
  DELVREMAININGAMOUNT        : abap.curr(23,2);
  DELVSOAMOUNT_ADJ           : abap.curr(23,2);


}
implemented by method
  ZCL_PREPAYMENT_ADJUST=>AMOUNT_TO_ADJUST;