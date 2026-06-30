#' @noRd
.onLoad <- function(libname, pkgname) {
  register_rule(rule_structure_required_dirs())
  register_rule(rule_dependency_forbidden())
  register_rule(rule_dependency_circular())
  register_rule(rule_complexity_cyclomatic())
  register_rule(rule_complexity_function_length())
  register_rule(rule_complexity_file_length())
  register_rule(rule_antipattern_global_assign())
  register_rule(rule_antipattern_assign())
  register_rule(rule_antipattern_setwd())
  register_rule(rule_antipattern_hardcoded_path())
  register_rule(rule_documentation_missing())
  invisible()
}
