@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Prepayment log - HTTP step detail'
@Metadata.allowExtensions: true
define view entity ZI_PREPAY_PROCESS_STEP
  as select from ztb_prepay_log
  association to parent ZI_PREPAY_PROCESS_LOG as _parent on $projection.CorrelationId = _parent.LogId

{
  key log_id        as LogId,
      correlation_id as CorrelationId,
      step_seq       as StepSeq,
      step_name      as StepName,
      http_method    as HttpMethod,
      http_status    as HttpStatus,
      uri            as Uri,
      response_body  as ResponseBody,
      
      _parent
}
  where step_seq > '00'
