create or replace package body api_naming_convention is

  /*
   * CONFIGURATION
   */

  -- OBJECT NAME PATTERNS
  -- objects
  gco_table_name_pattern constant gt_string := '';
  gco_view_name_pattern constant gt_string := '';
  gco_package_name_pattern constant gt_string := '';
  gco_procedure_name_pattern constant gt_string := '';
  gco_function_name_pattern constant gt_string := '';
  gco_row_trigger_name_pattern constant gt_string := '';
  gco_stmt_trigger_name_pattern constant gt_string := '';
  gco_type_name_pattern constant gt_string := '';
  gco_sequence_name_pattern constant gt_string := '';
  gco_mater_view_name_pattern constant gt_string := '';
  gco_synonym_name_pattern constant gt_string := '';
  -- constraints
  gco_primary_key_cst_pattern constant gt_string := '';
  gco_foreign_key_cst_pattern constant gt_string := '';
  gco_unique_key_cst_pattern constant gt_string := '';
  gco_check_cst_pattern constant gt_string := '';

  -- CODING PATTERNS
  -- package subprograms
  gco_package_procedure_pattern constant gt_string := '';
  gco_package_function_pattern constant gt_string := '';
  -- parameters
  gco_in_parameter_pattern constant gt_string := '';
  gco_out_parameter_pattern constant gt_string := '';
  gco_in_out_parameter_pattern constant gt_string := '';
  -- scope identifiers
  gco_local_identifier constant gt_string := '';
  gco_global_identifier constant gt_string := '';
  -- variables
  gco_variable_pattern constant gt_string := '';
  gco_constant_pattern constant gt_string := '';
  gco_exception_pattern constant gt_string := '';
  gco_cursor_pattern constant gt_string := '';
  gco_iterator_pattern constant gt_string := '';
  -- types
  gco_record_typ_pattern constant gt_string := '';
  gco_ind_tab_typ_pattern constant gt_string := '';
  gco_nes_tab_typ_pattern constant gt_string := '';
  gco_varray_typ_pattern constant gt_string := '';
  gco_ass_arr_typ_pattern constant gt_string := '';
  gco_ref_cur_typ_pattern constant gt_string := '';
  gco_subtype_pattern constant gt_string := '';

  -- EXCLUDED OBJECTS
  gco_excluded_objects_pattern constant gt_string := '(^API_NAMING_CONVENTION$)|'
                                                  || '(^OT_NAMING_VIOLATION$)|'
                                                  || '(^TT_NAMING_VIOLATIONS$)';


  /*
   * INTERNAL GLOBAL CONSTANTS
   * don't touch!
   */

  gco_object_name_violation constant gt_string := 'OBJECT NAME';
  gco_coding_violation constant gt_string := 'CODING';

  gco_scope_identifier constant gt_string := ':SCOPE:';
  gco_local_scope constant gt_string := 'LOCAL';
  gco_global_scope constant gt_string := 'GLOBAL';

  gco_case_insensitive_param constant gt_string := 'i';
  gco_case_sensitive_param constant gt_string := 'c';

  gco_definition_usage constant gt_string := 'DEFINITION';
  gco_declaration_usage constant gt_string := 'DECLARATION';


  /*
   * PRIVATE METHODS
   */

  function get_object_name_violations(
    in_object_type in gt_string,
    in_object_name_pattern in gt_string)
  return tt_naming_violations is
    lnt_violations tt_naming_violations;
  begin
    select ot_naming_violation(
             gco_object_name_violation,
             object_type,
             object_name,
             in_object_name_pattern,
             null, null, null, null)
    bulk collect into lnt_violations
    from user_objects
    where object_type = in_object_type
    and not regexp_like(object_name, gco_excluded_objects_pattern, gco_case_insensitive_param)
    and not regexp_like(object_name, in_object_name_pattern, gco_case_insensitive_param);

    return lnt_violations;
  end get_object_name_violations;

  function get_coding_violations(
    in_identifier_usage in gt_string,
    in_identifier_type in gt_string,
    in_identifier_pattern in gt_string)
  return tt_naming_violations is
    lnt_violations tt_naming_violations;
  begin
    select ot_naming_violation(
             gco_coding_violation,
             type,
             name,
             in_identifier_pattern,
             object_type,
             object_name,
             line || '/' || col,
             null)
    bulk collect into lnt_violations
    from user_identifiers
    where usage = in_identifier_usage
    and type = in_identifier_type
    and object_type != 'PACKAGE'
    and not regexp_like(object_name, gco_excluded_objects_pattern, gco_case_insensitive_param)
    and not regexp_like(name, in_identifier_pattern, gco_case_insensitive_param);

    return lnt_violations;
  end get_coding_violations;

  function get_scope_coding_violations(
    in_local_or_global_scope in gt_string,
    in_identifier_type in gt_string,
    in_identifier_pattern in gt_string)
  return tt_naming_violations is
    l_identifier_pattern gt_string;
    lnt_violations tt_naming_violations;
  begin
    if (in_local_or_global_scope = gco_local_scope) then
      l_identifier_pattern := replace(upper(in_identifier_pattern), upper(gco_scope_identifier), gco_local_identifier);
    else
      l_identifier_pattern := replace(upper(in_identifier_pattern), upper(gco_scope_identifier), gco_global_identifier);
    end if;

    select ot_naming_violation(
             gco_coding_violation,
             ui.type,
             ui.name,
             l_identifier_pattern,
             ui.object_type,
             ui.object_name,
             ui.line || '/' || ui.col,
             in_local_or_global_scope)
    bulk collect into lnt_violations
    from user_identifiers ui
    where ui.usage = gco_declaration_usage
    and ui.type = in_identifier_type
    and ((in_local_or_global_scope = gco_local_scope and ui.usage_context_id != 1) -- local
     or (in_local_or_global_scope = gco_global_scope and ui.usage_context_id = 1)) -- global
    and ui.usage_context_id != 0 -- omit objects
    and not exists (select usage_id
                    from user_identifiers ui2
                    where ui2.object_type = ui.object_type
                    and ui2.object_name = ui.object_name
                    and ui2.usage_id = ui.usage_context_id
                    and ui2.type in ('RECORD', 'OBJECT')
                    and ui2.usage = gco_declaration_usage)
    and not regexp_like(ui.object_name, gco_excluded_objects_pattern, gco_case_insensitive_param)
    and not regexp_like(ui.name, l_identifier_pattern, gco_case_insensitive_param);

    return lnt_violations;
  end get_scope_coding_violations;


  /*
   * PUBLIC METHODS
   */

  function all_violations
  return tt_naming_violations is
    lnt_violations tt_naming_violations;
  begin
    select ot_naming_violation(
             violation_type, element_type, element_name, violated_pattern,
             object_type, object_name, line_and_column, scope)
    bulk collect into lnt_violations
    from (select * from table(all_object_name_violations) union all
          select * from table(all_coding_violations));

    return lnt_violations;
  end all_violations;


  -- object name violations

  function all_object_name_violations
  return tt_naming_violations is
    lnt_violations tt_naming_violations;
  begin
    select ot_naming_violation(
             violation_type, element_type, element_name, violated_pattern,
             object_type, object_name, line_and_column, scope)
    bulk collect into lnt_violations
    from (select * from table(table_name_violations) union all
          select * from table(view_name_violations) union all
          select * from table(package_name_violations) union all
          select * from table(procedure_name_violations) union all
          select * from table(function_name_violations) union all
          select * from table(trigger_name_violations) union all
          select * from table(type_name_violations) union all
          select * from table(sequence_name_violations) union all
          select * from table(mater_view_name_violations) union all
          select * from table(synonym_name_violations) union all
          select * from table(constraint_name_violations));

    return lnt_violations;
  end all_object_name_violations;

  function table_name_violations
  return tt_naming_violations is
  begin
    return get_object_name_violations('TABLE', gco_table_name_pattern);
  end table_name_violations;

  function view_name_violations
  return tt_naming_violations is
  begin
    return get_object_name_violations('VIEW', gco_view_name_pattern);
  end view_name_violations;

  function package_name_violations
  return tt_naming_violations is
  begin
    return get_object_name_violations('PACKAGE', gco_package_name_pattern);
  end package_name_violations;

  function procedure_name_violations
  return tt_naming_violations is
  begin
    return get_object_name_violations('PROCEDURE', gco_procedure_name_pattern);
  end procedure_name_violations;

  function function_name_violations
  return tt_naming_violations is
  begin
    return get_object_name_violations('FUNCTION', gco_function_name_pattern);
  end function_name_violations;

  function trigger_name_violations
  return tt_naming_violations is
    lnt_violations tt_naming_violations;
  begin
    select *
    bulk collect into lnt_violations
    from (select ot_naming_violation(
                   gco_object_name_violation,
                   'TRIGGER',
                   trigger_name,
                   gco_row_trigger_name_pattern,
                   null, null, null, null)
          from user_triggers
          where trigger_type like '%ROW'
          and not regexp_like(trigger_name, gco_excluded_objects_pattern, gco_case_insensitive_param)
          and not regexp_like(trigger_name, gco_row_trigger_name_pattern, gco_case_insensitive_param)
          union all
          select ot_naming_violation(
                   gco_object_name_violation,
                   'TRIGGER',
                   trigger_name,
                   gco_stmt_trigger_name_pattern,
                   null, null, null, null)
          from user_triggers
          where trigger_type like '%STATEMENT'
          and not regexp_like(trigger_name, gco_excluded_objects_pattern, gco_case_insensitive_param)
          and not regexp_like(trigger_name, gco_stmt_trigger_name_pattern, gco_case_insensitive_param));

    return lnt_violations;
  end trigger_name_violations;

  function type_name_violations
  return tt_naming_violations is
  begin
    return get_object_name_violations('TYPE', gco_type_name_pattern);
  end type_name_violations;

  function sequence_name_violations
  return tt_naming_violations is
  begin
    return get_object_name_violations('SEQUENCE', gco_sequence_name_pattern);
  end sequence_name_violations;

  function mater_view_name_violations
  return tt_naming_violations is
  begin
    return get_object_name_violations('MATERIALIZED VIEW', gco_mater_view_name_pattern);
  end mater_view_name_violations;

  function synonym_name_violations
  return tt_naming_violations is
  begin
    return get_object_name_violations('SYNONYM', gco_synonym_name_pattern);
  end synonym_name_violations;

  function constraint_name_violations
  return tt_naming_violations is
    lnt_pk_cst_violations tt_naming_violations;
    lnt_fk_cst_violations tt_naming_violations;
    lnt_uk_cst_violations tt_naming_violations;
    lnt_check_cst_violations tt_naming_violations;
    lnt_violations tt_naming_violations;

    function translate_constraint_type(
      in_constraint_type in gt_string)
    return gt_string is
      l_constraint_type_translation gt_string;
    begin
      case in_constraint_type
        when 'P' then l_constraint_type_translation := 'PRIMARY KEY';
        when 'R' then l_constraint_type_translation := 'FOREIGN KEY';
        when 'U' then l_constraint_type_translation := 'UNIQUE KEY';
        when 'C' then l_constraint_type_translation := 'CHECK CONSTRAINT';
        else l_constraint_type_translation := 'UNKNOWN';
      end case;

      return l_constraint_type_translation;
    end translate_constraint_type;

    function violations_per_type(
      in_constraint_type in gt_string,
      in_constraint_name_pattern in gt_string)
    return tt_naming_violations is
      l_constraint_type_translation gt_string := translate_constraint_type(in_constraint_type);
      lnt_violations tt_naming_violations;
    begin
      select ot_naming_violation(
               gco_object_name_violation,
               l_constraint_type_translation,
               constraint_name,
               in_constraint_name_pattern,
               null, table_name, null, null)
      bulk collect into lnt_violations
      from user_constraints
      where constraint_type = in_constraint_type
      and constraint_name not like 'BIN$%' -- omit constraints from recycle bin
      and table_name not in (select name from user_snapshots) -- omit materialized view constraints
      and not regexp_like(constraint_name, gco_excluded_objects_pattern, gco_case_insensitive_param)
      and not regexp_like(constraint_name, in_constraint_name_pattern, gco_case_insensitive_param);

      return lnt_violations;
    end violations_per_type;
  begin
    lnt_pk_cst_violations := violations_per_type('P', gco_primary_key_cst_pattern);
    lnt_fk_cst_violations := violations_per_type('R', gco_foreign_key_cst_pattern);
    lnt_uk_cst_violations := violations_per_type('U', gco_unique_key_cst_pattern);
    lnt_check_cst_violations := violations_per_type('C', gco_check_cst_pattern);

    select ot_naming_violation(
             violation_type, element_type, element_name, violated_pattern,
             object_type, object_name, line_and_column, scope)
    bulk collect into lnt_violations
    from (select * from table(lnt_pk_cst_violations) union all
          select * from table(lnt_fk_cst_violations) union all
          select * from table(lnt_uk_cst_violations) union all
          select * from table(lnt_check_cst_violations));

    return lnt_violations;
  end constraint_name_violations;


  -- coding violations

  function all_coding_violations
  return tt_naming_violations is
    lnt_violations tt_naming_violations;
  begin
    select ot_naming_violation(
             violation_type, element_type, element_name, violated_pattern,
             object_type, object_name, line_and_column, scope)
    bulk collect into lnt_violations
    from (select * from table(pck_subprogram_violations) union all
          select * from table(parameter_violations) union all
          select * from table(all_variable_violations));

    return lnt_violations;
  end all_coding_violations;

  function pck_subprogram_violations
  return tt_naming_violations is
    lnt_procedure_violations tt_naming_violations := get_coding_violations(gco_definition_usage, 'PROCEDURE', gco_package_procedure_pattern);
    lnt_function_violations tt_naming_violations := get_coding_violations(gco_definition_usage, 'FUNCTION', gco_package_function_pattern);
    lnt_violations tt_naming_violations;
  begin
    select ot_naming_violation(
             violation_type, element_type, element_name, violated_pattern,
             object_type, object_name, line_and_column, scope)
    bulk collect into lnt_violations
    from (select * from table(lnt_procedure_violations) union all
          select * from table(lnt_function_violations));

    return lnt_violations;
  end pck_subprogram_violations;

  function parameter_violations
  return tt_naming_violations is
    lnt_in_param_violations tt_naming_violations := get_coding_violations(gco_declaration_usage, 'FORMAL IN', gco_in_parameter_pattern);
    lnt_out_param_violations tt_naming_violations := get_coding_violations(gco_declaration_usage, 'FORMAL OUT', gco_out_parameter_pattern);
    lnt_in_out_param_violations tt_naming_violations := get_coding_violations(gco_declaration_usage, 'FORMAL IN OUT', gco_in_out_parameter_pattern);
    lnt_violations tt_naming_violations;
  begin
    select ot_naming_violation(
             violation_type, element_type, element_name, violated_pattern,
             object_type, object_name, line_and_column, scope)
    bulk collect into lnt_violations
    from (select * from table(lnt_in_param_violations) union all
          select * from table(lnt_out_param_violations) union all
          select * from table(lnt_in_out_param_violations));

    return lnt_violations;
  end parameter_violations;

  function all_variable_violations
  return tt_naming_violations is
    lnt_violations tt_naming_violations;
  begin
    select ot_naming_violation(
             violation_type, element_type, element_name, violated_pattern,
             object_type, object_name, line_and_column, scope)
    bulk collect into lnt_violations
    from (select * from table(local_variable_violations) union all
          select * from table(global_variable_violations));

    return lnt_violations;
  end all_variable_violations;

  function local_variable_violations
  return tt_naming_violations is
    lnt_variable_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'VARIABLE', gco_variable_pattern);
    lnt_constant_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'CONSTANT', gco_constant_pattern);
    lnt_exception_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'EXCEPTION', gco_exception_pattern);
    lnt_cursor_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'CURSOR', gco_cursor_pattern);
    lnt_iterator_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'ITERATOR', gco_iterator_pattern);

    lnt_record_typ_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'RECORD', gco_record_typ_pattern);
    lnt_ind_tab_typ_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'INDEX TABLE', gco_ind_tab_typ_pattern);
    lnt_nes_tab_typ_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'NESTED TABLE', gco_nes_tab_typ_pattern);
    lnt_varray_typ_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'VARRAY', gco_varray_typ_pattern);
    lnt_ass_arr_typ_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'ASSOCIATIVE ARRAY', gco_ass_arr_typ_pattern);
    lnt_ref_cur_typ_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'REFCURSOR', gco_ref_cur_typ_pattern);
    lnt_subtype_violations tt_naming_violations := get_scope_coding_violations(gco_local_scope, 'SUBTYPE', gco_subtype_pattern);
    lnt_violations tt_naming_violations;
  begin
    select ot_naming_violation(
             violation_type, element_type, element_name, violated_pattern,
             object_type, object_name, line_and_column, scope)
    bulk collect into lnt_violations
    from (select * from table(lnt_variable_violations) union all
          select * from table(lnt_constant_violations) union all
          select * from table(lnt_exception_violations) union all
          select * from table(lnt_cursor_violations) union all
          select * from table(lnt_iterator_violations) union all
          select * from table(lnt_record_typ_violations) union all
          select * from table(lnt_ind_tab_typ_violations) union all
          select * from table(lnt_nes_tab_typ_violations) union all
          select * from table(lnt_varray_typ_violations) union all
          select * from table(lnt_ass_arr_typ_violations) union all
          select * from table(lnt_ref_cur_typ_violations) union all
          select * from table(lnt_subtype_violations));

    return lnt_violations;
  end local_variable_violations;

  function global_variable_violations
  return tt_naming_violations is
    lnt_variable_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'VARIABLE', gco_variable_pattern);
    lnt_constant_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'CONSTANT', gco_constant_pattern);
    lnt_exception_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'EXCEPTION', gco_exception_pattern);
    lnt_cursor_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'CURSOR', gco_cursor_pattern);

    lnt_record_typ_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'RECORD', gco_record_typ_pattern);
    lnt_ind_tab_typ_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'INDEX TABLE', gco_ind_tab_typ_pattern);
    lnt_nes_tab_typ_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'NESTED TABLE', gco_nes_tab_typ_pattern);
    lnt_varray_typ_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'VARRAY', gco_varray_typ_pattern);
    lnt_ass_arr_typ_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'ASSOCIATIVE ARRAY', gco_ass_arr_typ_pattern);
    lnt_ref_cur_typ_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'REFCURSOR', gco_ref_cur_typ_pattern);
    lnt_subtype_violations tt_naming_violations := get_scope_coding_violations(gco_global_scope, 'SUBTYPE', gco_subtype_pattern);
    lnt_violations tt_naming_violations;
  begin
    select ot_naming_violation(
             violation_type, element_type, element_name, violated_pattern,
             object_type, object_name, line_and_column, scope)
    bulk collect into lnt_violations
    from (select * from table(lnt_variable_violations) union all
          select * from table(lnt_constant_violations) union all
          select * from table(lnt_exception_violations) union all
          select * from table(lnt_cursor_violations) union all
          select * from table(lnt_record_typ_violations) union all
          select * from table(lnt_ind_tab_typ_violations) union all
          select * from table(lnt_nes_tab_typ_violations) union all
          select * from table(lnt_varray_typ_violations) union all
          select * from table(lnt_ass_arr_typ_violations) union all
          select * from table(lnt_ref_cur_typ_violations) union all
          select * from table(lnt_subtype_violations));

    return lnt_violations;
  end global_variable_violations;

end api_naming_convention;