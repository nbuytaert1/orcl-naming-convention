create or replace package api_naming_convention is

  subtype gt_string is varchar2(32767);

  function all_violations return tt_naming_violations;

  -- object name violations
  function all_object_name_violations return tt_naming_violations;
  function table_name_violations return tt_naming_violations;
  function view_name_violations return tt_naming_violations;
  function package_name_violations return tt_naming_violations;
  function procedure_name_violations return tt_naming_violations;
  function function_name_violations return tt_naming_violations;
  function trigger_name_violations return tt_naming_violations;
  function type_name_violations return tt_naming_violations;
  function sequence_name_violations return tt_naming_violations;
  function mater_view_name_violations return tt_naming_violations;
  function synonym_name_violations return tt_naming_violations;
  function constraint_name_violations return tt_naming_violations;

  -- coding violations
  function all_coding_violations return tt_naming_violations;
  function pck_subprogram_violations return tt_naming_violations;
  function parameter_violations return tt_naming_violations;
  function all_variable_violations return tt_naming_violations;
  function local_variable_violations return tt_naming_violations;
  function global_variable_violations return tt_naming_violations;

end api_naming_convention;