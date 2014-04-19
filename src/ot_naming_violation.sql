create or replace type ot_naming_violation force is object(
  violation_type varchar2(32767),
  element_type varchar2(32767),
  element_name varchar2(32767),
  violated_pattern varchar2(32767),
  object_type varchar2(32767),
  object_name varchar2(32767),
  line_and_column varchar2(32767),
  scope varchar2(32767)
);