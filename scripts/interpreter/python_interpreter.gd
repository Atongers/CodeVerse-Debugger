extends RefCounted
class_name PythonInterpreter

const KNOWN_FUNCTIONS := [
	"print",
	"int",
	"str",
	"abs",
	"len",
	"matikan_laser_oranye",
	"aktifkan_elevator",
	"set_tegangan_laser_biru",
	"buka_gerbang_exit",
	"matikan_laser_patroli",
	"sinkronisasi_elevator",
	"matikan_scanner",
	"kalibrasi_crane",
	"buka_exit_level_2",
	"atur_plasma",
	"gerak_crane",
	"atur_elevator",
	"buka_firewall",
	"buka_exit_level_3",
	"stabilkan_gerbang_kota",
	"kalibrasi_pendingin",
	"set_filter_iff",
	"aktifkan_jembatan_overpass",
	"nonaktifkan_perisai_boss",
	"pulihkan_gatekeeper_ai",
	"rakit_item",
]


static func run_script(source_code: String, allowed_calls: Array[String] = []) -> Dictionary:
	var lines: PackedStringArray = source_code.split("\n")
	var env: Dictionary = {}
	var steps: Array[Dictionary] = []
	var all_outputs: Array[String] = []
	var all_calls: Array[Dictionary] = []

	var parsed_lines: Array[Dictionary] = []
	for idx in range(lines.size()):
		var line_num: int = idx + 1
		var raw_line: String = lines[idx]
		var code_line: String = _strip_comment(raw_line).strip_edges()
		if code_line.is_empty():
			continue
		var indent_spaces: int = _count_indent_spaces(raw_line)
		parsed_lines.append({
			"line": line_num,
			"raw": raw_line,
			"code": code_line,
			"indent": indent_spaces,
		})

	# Pre-check syntax and indentation structure across lines
	for p_idx in range(parsed_lines.size()):
		var item: Dictionary = parsed_lines[p_idx]
		var line_num: int = int(item["line"])
		var raw_line: String = str(item["raw"])
		var code_line: String = str(item["code"])
		var indent: int = int(item["indent"])

		# 1. Check basic quote/paren/header syntax first (so missing ':' is caught before indent errors)
		var syn_info: Dictionary = _check_line_syntax_v2(raw_line, code_line, line_num)
		if not syn_info.is_empty():
			return _make_error_result(steps, env, all_outputs, all_calls, line_num, code_line, str(syn_info["message"]), str(syn_info["type"]))

		# 2. Check indentation validity relative to previous non-empty line
		if p_idx == 0:
			if indent > 0:
				var msg := "IndentationError (Baris %d): Spasi/tab di awal baris tidak diperlukan di sini." % line_num
				return _make_error_result(steps, env, all_outputs, all_calls, line_num, code_line, msg, "IndentationError")
		else:
			var prev_item: Dictionary = parsed_lines[p_idx - 1]
			var prev_code: String = str(prev_item["code"])
			var prev_indent: int = int(prev_item["indent"])
			var prev_is_header: bool = _is_block_header(prev_code)

			if prev_is_header:
				if indent <= prev_indent:
					var msg := "IndentationError (Baris %d): Baris di dalam blok 'if/elif/else' harus menjorok ke dalam (gunakan 4 spasi atau Tab)." % line_num
					return _make_error_result(steps, env, all_outputs, all_calls, line_num, code_line, msg, "IndentationError")
			else:
				if indent > prev_indent:
					var msg := "IndentationError (Baris %d): Spasi/tab di awal baris tidak diperlukan di sini." % line_num
					return _make_error_result(steps, env, all_outputs, all_calls, line_num, code_line, msg, "IndentationError")

		# 3. If the last line in the script is a block header, it has an empty body
		if _is_block_header(code_line) and p_idx == parsed_lines.size() - 1:
			var msg := "IndentationError (Baris %d): Baris di dalam blok 'if/elif/else' harus menjorok ke dalam (gunakan 4 spasi atau Tab)." % line_num
			return _make_error_result(steps, env, all_outputs, all_calls, line_num, code_line, msg, "IndentationError")

	# Execute with conditional block stack
	var block_stack: Array[Dictionary] = []

	for p_idx in range(parsed_lines.size()):
		var item: Dictionary = parsed_lines[p_idx]
		var line_num: int = int(item["line"])
		var code_line: String = str(item["code"])
		var indent: int = int(item["indent"])
		var kw: String = _get_header_keyword(code_line)

		if kw == "if":
			while not block_stack.is_empty() and int(block_stack.back()["indent"]) >= indent:
				block_stack.pop_back()
			var parent_active: bool = _is_stack_active(block_stack, indent)
			if not parent_active:
				block_stack.append({"indent": indent, "branch_taken": true, "active": false})
				continue
			var cond_str: String = code_line.substr(2, code_line.length() - 3).strip_edges()
			var cond_res: Dictionary = _eval_expr(cond_str, line_num, env)
			if cond_res.has("error"):
				var err_d: Dictionary = cond_res["error"]
				return _make_error_result(steps, env, all_outputs, all_calls, line_num, code_line, str(err_d.get("message", "Terjadi kesalahan.")), str(err_d.get("type", "RuntimeError")))
			var taken: bool = _to_bool(cond_res["value"])
			steps.append({
				"line": line_num,
				"code": code_line,
				"env": env.duplicate(true),
				"outputs": [] as Array[String],
				"call": {},
				"error": "",
				"error_type": "",
			})
			block_stack.append({"indent": indent, "branch_taken": taken, "active": taken})
			continue

		elif kw == "elif":
			while not block_stack.is_empty() and int(block_stack.back()["indent"]) > indent:
				block_stack.pop_back()
			if block_stack.is_empty() or int(block_stack.back()["indent"]) != indent:
				var msg := "SyntaxError (Baris %d): 'elif' harus berada sejajar setelah blok 'if'." % line_num
				return _make_error_result(steps, env, all_outputs, all_calls, line_num, code_line, msg, "SyntaxError")
			var parent_active: bool = _is_stack_active(block_stack, indent)
			var frame: Dictionary = block_stack.back()
			if not parent_active or bool(frame["branch_taken"]):
				frame["active"] = false
				block_stack[block_stack.size() - 1] = frame
				continue
			var cond_str: String = code_line.substr(4, code_line.length() - 5).strip_edges()
			var cond_res: Dictionary = _eval_expr(cond_str, line_num, env)
			if cond_res.has("error"):
				var err_d: Dictionary = cond_res["error"]
				return _make_error_result(steps, env, all_outputs, all_calls, line_num, code_line, str(err_d.get("message", "Terjadi kesalahan.")), str(err_d.get("type", "RuntimeError")))
			var taken: bool = _to_bool(cond_res["value"])
			steps.append({
				"line": line_num,
				"code": code_line,
				"env": env.duplicate(true),
				"outputs": [] as Array[String],
				"call": {},
				"error": "",
				"error_type": "",
			})
			frame["branch_taken"] = taken
			frame["active"] = taken
			block_stack[block_stack.size() - 1] = frame
			continue

		elif kw == "else":
			while not block_stack.is_empty() and int(block_stack.back()["indent"]) > indent:
				block_stack.pop_back()
			if block_stack.is_empty() or int(block_stack.back()["indent"]) != indent:
				var msg := "SyntaxError (Baris %d): 'else' harus berada sejajar setelah blok 'if' atau 'elif'." % line_num
				return _make_error_result(steps, env, all_outputs, all_calls, line_num, code_line, msg, "SyntaxError")
			var parent_active: bool = _is_stack_active(block_stack, indent)
			var frame: Dictionary = block_stack.back()
			if not parent_active or bool(frame["branch_taken"]):
				frame["active"] = false
				block_stack[block_stack.size() - 1] = frame
				continue
			steps.append({
				"line": line_num,
				"code": code_line,
				"env": env.duplicate(true),
				"outputs": [] as Array[String],
				"call": {},
				"error": "",
				"error_type": "",
			})
			frame["branch_taken"] = true
			frame["active"] = true
			block_stack[block_stack.size() - 1] = frame
			continue

		# Regular statement: pop any block frames at or deeper than current indent
		while not block_stack.is_empty() and int(block_stack.back()["indent"]) >= indent:
			block_stack.pop_back()

		if not _is_stack_active(block_stack, indent + 1):
			continue

		var step_outputs: Array[String] = []
		var step_call: Dictionary = {}
		var err_info: Dictionary = _execute_statement(code_line, line_num, env, step_outputs, step_call, allowed_calls)

		if not err_info.is_empty():
			var err_msg: String = err_info.get("message", "Terjadi kesalahan.")
			var err_type: String = err_info.get("type", "RuntimeError")
			return _make_error_result(steps, env, all_outputs, all_calls, line_num, code_line, err_msg, err_type, step_outputs, step_call)

		for o in step_outputs:
			all_outputs.append(o)
		if not step_call.is_empty():
			all_calls.append(step_call)

		steps.append({
			"line": line_num,
			"code": code_line,
			"env": env.duplicate(true),
			"outputs": step_outputs,
			"call": step_call,
			"error": "",
			"error_type": "",
		})

	return {
		"ok": true,
		"steps": steps,
		"env": env,
		"outputs": all_outputs,
		"calls": all_calls,
		"error": "",
		"error_type": "",
		"error_line": -1,
	}


static func _make_error_result(
	steps: Array[Dictionary],
	env: Dictionary,
	all_outputs: Array[String],
	all_calls: Array[Dictionary],
	line_num: int,
	code_line: String,
	err_msg: String,
	err_type: String,
	step_outputs: Array[String] = [],
	step_call: Dictionary = {}
) -> Dictionary:
	steps.append({
		"line": line_num,
		"code": code_line,
		"env": env.duplicate(true),
		"outputs": step_outputs,
		"call": step_call,
		"error": err_msg,
		"error_type": err_type,
	})
	return {
		"ok": false,
		"steps": steps,
		"env": env,
		"outputs": all_outputs,
		"calls": all_calls,
		"error": err_msg,
		"error_type": err_type,
		"error_line": line_num,
	}


static func _count_indent_spaces(raw: String) -> int:
	var count := 0
	for i in range(raw.length()):
		var c := raw[i]
		if c == " ":
			count += 1
		elif c == "\t":
			count += 4
		else:
			break
	return count


static func _get_header_keyword(code: String) -> String:
	if code == "if" or code.begins_with("if ") or code.begins_with("if(") or code.begins_with("if:"):
		return "if"
	if code == "elif" or code.begins_with("elif ") or code.begins_with("elif(") or code.begins_with("elif:"):
		return "elif"
	if code == "else" or code.begins_with("else:") or code.begins_with("else "):
		return "else"
	return ""


static func _is_block_header(code: String) -> bool:
	return not _get_header_keyword(code).is_empty() and code.ends_with(":")


static func _is_stack_active(stack: Array[Dictionary], max_indent_exclusive: int) -> bool:
	for f in stack:
		if int(f["indent"]) < max_indent_exclusive and not bool(f["active"]):
			return false
	return true


static func _to_bool(v: Variant) -> bool:
	if typeof(v) == TYPE_BOOL:
		return bool(v)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return not is_zero_approx(float(v))
	if typeof(v) == TYPE_STRING:
		return not str(v).is_empty()
	return v != null


static func _strip_comment(raw: String) -> String:
	var in_single := false
	var in_double := false
	for i in range(raw.length()):
		var ch := raw[i]
		if ch == "'" and not in_double:
			in_single = not in_single
		elif ch == "\"" and not in_single:
			in_double = not in_double
		elif ch == "#" and not in_single and not in_double:
			return raw.substr(0, i)
	return raw


static func _check_line_syntax_v2(raw: String, code: String, line_num: int) -> Dictionary:
	# 1. Unclosed quotes & parentheses check
	var in_single := false
	var in_double := false
	var paren_depth := 0
	for i in range(raw.length()):
		var ch := raw[i]
		if ch == "#" and not in_single and not in_double:
			break
		if ch == "'" and not in_double:
			in_single = not in_single
		elif ch == "\"" and not in_single:
			in_double = not in_double
		elif not in_single and not in_double:
			if ch == "(":
				paren_depth += 1
			elif ch == ")":
				paren_depth -= 1
				if paren_depth < 0:
					return {
						"type": "SyntaxError",
						"message": "SyntaxError (Baris %d): Tanda kurung tutup ')' berlebih tanpa pasangannya." % line_num
					}

	if in_single or in_double:
		return {
			"type": "SyntaxError",
			"message": "SyntaxError (Baris %d): Tanda kutip teks (string) belum ditutup." % line_num
		}
	if paren_depth != 0:
		return {
			"type": "SyntaxError",
			"message": "SyntaxError (Baris %d): Tanda kurung '(' belum ditutup dengan ')'." % line_num
		}

	# 2. Check conditional header syntax (BUG-11 missing ':' & BUG-13 '=' in condition)
	var kw := _get_header_keyword(code)
	if not kw.is_empty():
		if not code.ends_with(":"):
			return {
				"type": "SyntaxError",
				"message": "SyntaxError (Baris %d): Pernyataan '%s' wajib diakhiri tanda titik dua ':'." % [line_num, kw]
			}
		if kw == "if" or kw == "elif":
			var cond_str := code.substr(kw.length(), code.length() - kw.length() - 1).strip_edges()
			if cond_str.is_empty():
				return {
					"type": "SyntaxError",
					"message": "SyntaxError (Baris %d): Kondisi setelah '%s' tidak boleh kosong." % [line_num, kw]
				}
			if _find_top_level_assign(cond_str) != -1:
				return {
					"type": "SyntaxError",
					"message": "SyntaxError (Baris %d): Di dalam kondisi 'if/elif', gunakan dua tanda sama dengan '==' untuk membandingkan nilai, bukan '='." % line_num
				}
		elif kw == "else":
			var after_else := code.substr(4, code.length() - 5).strip_edges()
			if not after_else.is_empty():
				return {
					"type": "SyntaxError",
					"message": "SyntaxError (Baris %d): Pernyataan 'else:' tidak boleh diikuti kondisi (gunakan 'elif' jika butuh kondisi)." % line_num
				}
		return {}

	# 3. For regular statements, catch accidental '==' used as assignment when no '=' is present
	if code.find("==") != -1 and not code.begins_with("print(") and _find_top_level_assign(code) == -1:
		return {
			"type": "SyntaxError",
			"message": "SyntaxError (Baris %d): Gunakan satu tanda '=' untuk mengisi variabel, bukan '=='." % line_num
		}

	return {}


static func _execute_statement(
	code: String,
	line_num: int,
	env: Dictionary,
	step_outputs: Array[String],
	step_call: Dictionary,
	allowed_calls: Array[String]
) -> Dictionary:
	var eq_pos := _find_top_level_assign(code)
	if eq_pos == -1:
		var paren_open := code.find("(")
		if paren_open != -1 and code.ends_with(")"):
			var fn_name := code.substr(0, paren_open).strip_edges()
			var args_str := code.substr(paren_open + 1, code.length() - paren_open - 2).strip_edges()
			return _eval_function_call(fn_name, args_str, line_num, env, step_outputs, step_call, allowed_calls)
		else:
			return {
				"type": "SyntaxError",
				"message": "SyntaxError (Baris %d): Baris '%s' bukan perintah yang valid. Gunakan 'variabel = nilai' atau panggil fungsi seperti 'print(...)'." % [line_num, code]
			}

	var lhs := code.substr(0, eq_pos).strip_edges()
	var rhs := code.substr(eq_pos + 1).strip_edges()
	var compound_op := ""
	if lhs.ends_with("+") or lhs.ends_with("-") or lhs.ends_with("*") or lhs.ends_with("/"):
		compound_op = lhs.substr(lhs.length() - 1, 1)
		lhs = lhs.substr(0, lhs.length() - 1).strip_edges()

	if not _is_valid_identifier(lhs):
		return {
			"type": "SyntaxError",
			"message": "SyntaxError (Baris %d): Nama variabel '%s' tidak valid. Gunakan huruf/garis bawah tanpa spasi." % [line_num, lhs]
		}
	if rhs.is_empty():
		return {
			"type": "SyntaxError",
			"message": "SyntaxError (Baris %d): Nilai di sebelah kanan tanda '=' masih kosong." % line_num
		}

	var eval_res: Dictionary = _eval_expr(rhs, line_num, env)
	if eval_res.has("error"):
		return eval_res["error"]

	var val = eval_res["value"]
	if not compound_op.is_empty():
		if not env.has(lhs):
			return {
				"type": "NameError",
				"message": "NameError (Baris %d): Variabel '%s' belum memiliki nilai awal sebelum '%s='." % [line_num, lhs, compound_op]
			}
		var bin_res: Dictionary = _apply_binary_op(env[lhs], compound_op, val, line_num)
		if bin_res.has("error"):
			return bin_res["error"]
		val = bin_res["value"]

	env[lhs] = val
	return {}


static func _eval_function_call(
	fn_name: String,
	args_str: String,
	line_num: int,
	env: Dictionary,
	step_outputs: Array[String],
	step_call: Dictionary,
	allowed_calls: Array[String]
) -> Dictionary:
	if not _is_valid_identifier(fn_name):
		return {
			"type": "SyntaxError",
			"message": "SyntaxError (Baris %d): Nama fungsi '%s' tidak valid." % [line_num, fn_name]
		}

	var all_valid_fns: Array[String] = ["print", "int", "str", "abs", "len"]
	for ac in allowed_calls:
		if not all_valid_fns.has(ac):
			all_valid_fns.append(ac)
	for kf in KNOWN_FUNCTIONS:
		if not all_valid_fns.has(kf):
			all_valid_fns.append(kf)

	if not all_valid_fns.has(fn_name):
		var suggestion := _suggest_identifier(fn_name, all_valid_fns)
		var hint_suffix := (" Apakah maksudmu '%s'?" % suggestion) if not suggestion.is_empty() else ""
		return {
			"type": "NameError",
			"message": "NameError (Baris %d): Nama fungsi '%s' tidak dikenal.%s" % [line_num, fn_name, hint_suffix]
		}

	var args: Array = []
	if not args_str.is_empty():
		var parts: Array[String] = _split_top_level_commas(args_str)
		for p in parts:
			var er: Dictionary = _eval_expr(p.strip_edges(), line_num, env)
			if er.has("error"):
				return er["error"]
			args.append(er["value"])

	if fn_name == "print":
		var out_parts: PackedStringArray = []
		for a in args:
			out_parts.append(_format_py_value(a))
		step_outputs.append(" ".join(out_parts))
		return {}

	if args.size() != 1:
		return {
			"type": "TypeError",
			"message": "TypeError (Baris %d): Fungsi '%s()' membutuhkan tepat 1 argumen, tetapi diberikan %d." % [line_num, fn_name, args.size()]
		}

	step_call["name"] = fn_name
	step_call["args"] = args
	step_call["line"] = line_num
	return {}


static func _eval_expr(expr: String, line_num: int, env: Dictionary) -> Dictionary:
	var s := expr.strip_edges()
	if s.is_empty():
		return {"error": {"type": "SyntaxError", "message": "SyntaxError (Baris %d): Ekspresi kosong." % line_num}}

	while s.begins_with("(") and s.ends_with(")") and _parens_wrap_entire(s):
		s = s.substr(1, s.length() - 2).strip_edges()

	# 1. Boolean 'or' (lowest precedence)
	var or_pos := _find_rightmost_keyword_op(s, "or")
	if or_pos != -1:
		var left_str := s.substr(0, or_pos).strip_edges()
		var right_str := s.substr(or_pos + 2).strip_edges()
		var l_res: Dictionary = _eval_expr(left_str, line_num, env)
		if l_res.has("error"):
			return l_res
		var r_res: Dictionary = _eval_expr(right_str, line_num, env)
		if r_res.has("error"):
			return r_res
		return {"value": _to_bool(l_res["value"]) or _to_bool(r_res["value"])}

	# 2. Boolean 'and'
	var and_pos := _find_rightmost_keyword_op(s, "and")
	if and_pos != -1:
		var left_str := s.substr(0, and_pos).strip_edges()
		var right_str := s.substr(and_pos + 3).strip_edges()
		var l_res: Dictionary = _eval_expr(left_str, line_num, env)
		if l_res.has("error"):
			return l_res
		var r_res: Dictionary = _eval_expr(right_str, line_num, env)
		if r_res.has("error"):
			return r_res
		return {"value": _to_bool(l_res["value"]) and _to_bool(r_res["value"])}

	# 3. Unary 'not'
	if s.begins_with("not ") or s.begins_with("not("):
		var sub_str := s.substr(3).strip_edges()
		var u_res: Dictionary = _eval_expr(sub_str, line_num, env)
		if u_res.has("error"):
			return u_res
		return {"value": not _to_bool(u_res["value"])}

	# 4. Comparison operators: ==, !=, <=, >=, <, >
	var cmp_info := _find_rightmost_cmp_op(s)
	if cmp_info.has("index"):
		var c_idx: int = int(cmp_info["index"])
		var c_op: String = str(cmp_info["op"])
		var left_str := s.substr(0, c_idx).strip_edges()
		var right_str := s.substr(c_idx + c_op.length()).strip_edges()
		var l_res: Dictionary = _eval_expr(left_str, line_num, env)
		if l_res.has("error"):
			return l_res
		var r_res: Dictionary = _eval_expr(right_str, line_num, env)
		if r_res.has("error"):
			return r_res
		return _apply_cmp_op(l_res["value"], c_op, r_res["value"], line_num)

	# 5. Binary addition / subtraction
	var add_sub_pos := _find_rightmost_top_op(s, ["+", "-"])
	if add_sub_pos != -1:
		var op_ch := s[add_sub_pos]
		var left_str := s.substr(0, add_sub_pos).strip_edges()
		var right_str := s.substr(add_sub_pos + 1).strip_edges()
		if left_str.is_empty():
			var u_res: Dictionary = _eval_expr(right_str, line_num, env)
			if u_res.has("error"):
				return u_res
			var u_val = u_res["value"]
			if typeof(u_val) != TYPE_INT and typeof(u_val) != TYPE_FLOAT:
				return {"error": {"type": "TypeError", "message": "TypeError (Baris %d): Operator '%s' hanya untuk angka." % [line_num, op_ch]}}
			return {"value": -u_val if op_ch == "-" else u_val}

		var l_res: Dictionary = _eval_expr(left_str, line_num, env)
		if l_res.has("error"):
			return l_res
		var r_res: Dictionary = _eval_expr(right_str, line_num, env)
		if r_res.has("error"):
			return r_res
		return _apply_binary_op(l_res["value"], op_ch, r_res["value"], line_num)

	# 6. Binary *, //, /, %
	var mul_pos := _find_rightmost_mul_op(s)
	if mul_pos.has("index"):
		var idx: int = mul_pos["index"]
		var op_str: String = mul_pos["op"]
		var left_str := s.substr(0, idx).strip_edges()
		var right_str := s.substr(idx + op_str.length()).strip_edges()
		var l_res: Dictionary = _eval_expr(left_str, line_num, env)
		if l_res.has("error"):
			return l_res
		var r_res: Dictionary = _eval_expr(right_str, line_num, env)
		if r_res.has("error"):
			return r_res
		return _apply_binary_op(l_res["value"], op_str, r_res["value"], line_num)

	# 7. Built-in conversion functions: int(x), str(x), abs(x), len(x)
	var paren_idx := s.find("(")
	if paren_idx != -1 and s.ends_with(")"):
		var fn := s.substr(0, paren_idx).strip_edges()
		var inner := s.substr(paren_idx + 1, s.length() - paren_idx - 2).strip_edges()
		var arg_res: Dictionary = _eval_expr(inner, line_num, env)
		if arg_res.has("error"):
			return arg_res
		var v = arg_res["value"]
		if fn == "int":
			if typeof(v) == TYPE_STRING and v.is_valid_int():
				return {"value": v.to_int()}
			elif typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
				return {"value": int(v)}
			return {"error": {"type": "ValueError", "message": "ValueError (Baris %d): Tidak bisa mengubah '%s' menjadi bilangan bulat (int)." % [line_num, str(v)]}}
		elif fn == "str":
			return {"value": _format_py_value(v)}
		elif fn == "abs":
			if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
				return {"value": abs(v)}
			return {"error": {"type": "TypeError", "message": "TypeError (Baris %d): abs() membutuhkan angka." % line_num}}
		elif fn == "len":
			if typeof(v) == TYPE_STRING:
				return {"value": v.length()}
			elif typeof(v) == TYPE_ARRAY:
				return {"value": v.size()}
			return {"error": {"type": "TypeError", "message": "TypeError (Baris %d): len() membutuhkan string atau list." % line_num}}

	# 8. String literal
	if (s.begins_with("\"") and s.ends_with("\"")) or (s.begins_with("'") and s.ends_with("'")):
		if s.length() >= 2:
			return {"value": s.substr(1, s.length() - 2)}

	# 9. Boolean literal
	if s == "True":
		return {"value": true}
	if s == "False":
		return {"value": false}

	# 10. Numeric literal
	if s.is_valid_int():
		return {"value": s.to_int()}
	if s.is_valid_float():
		return {"value": s.to_float()}

	# 11. Variable lookup
	if _is_valid_identifier(s):
		if env.has(s):
			return {"value": env[s]}
		var keys: Array[String] = []
		for k in env.keys():
			keys.append(str(k))
		var sug := _suggest_identifier(s, keys)
		var sug_text := (" Apakah maksudmu '%s'?" % sug) if not sug.is_empty() else ""
		return {
			"error": {
				"type": "NameError",
				"message": "NameError (Baris %d): Variabel '%s' belum didefinisikan.%s" % [line_num, s, sug_text]
			}
		}

	return {
		"error": {
			"type": "SyntaxError",
			"message": "SyntaxError (Baris %d): Tidak dapat memahami ekspresi '%s'." % [line_num, s]
		}
	}


static func _apply_cmp_op(left: Variant, op: String, right: Variant, line_num: int) -> Dictionary:
	var lt := typeof(left)
	var rt := typeof(right)
	if op == "==":
		return {"value": left == right}
	if op == "!=":
		return {"value": left != right}

	var l_num := (lt == TYPE_INT or lt == TYPE_FLOAT)
	var r_num := (rt == TYPE_INT or rt == TYPE_FLOAT)
	if not l_num or not r_num:
		return {
			"error": {
				"type": "TypeError",
				"message": "TypeError (Baris %d): Perbandingan '%s' membutuhkan angka, bukan '%s' dan '%s'." % [line_num, op, str(left), str(right)]
			}
		}

	var lf := float(left)
	var rf := float(right)
	match op:
		"<":
			return {"value": lf < rf}
		">":
			return {"value": lf > rf}
		"<=":
			return {"value": lf <= rf}
		">=":
			return {"value": lf >= rf}

	return {"error": {"type": "SyntaxError", "message": "SyntaxError (Baris %d): Operator perbandingan '%s' tidak dikenal." % [line_num, op]}}


static func _apply_binary_op(left, op: String, right, line_num: int) -> Dictionary:
	var lt := typeof(left)
	var rt := typeof(right)

	if op == "+":
		if lt == TYPE_STRING and rt == TYPE_STRING:
			return {"value": left + right}
		if (lt == TYPE_STRING and (rt == TYPE_INT or rt == TYPE_FLOAT)) or ((lt == TYPE_INT or lt == TYPE_FLOAT) and rt == TYPE_STRING):
			return {
				"error": {
					"type": "TypeError",
					"message": "TypeError (Baris %d): Tidak bisa menjumlahkan teks (str \"%s\") dengan angka (int %s). Hapus tanda kutip pada angka agar bisa dijumlahkan!" % [line_num, str(left), str(right)]
				}
			}

	var l_num := (lt == TYPE_INT or lt == TYPE_FLOAT)
	var r_num := (rt == TYPE_INT or rt == TYPE_FLOAT)
	if not l_num or not r_num:
		return {
			"error": {
				"type": "TypeError",
				"message": "TypeError (Baris %d): Operasi '%s' tidak didukung antara '%s' dan '%s'." % [line_num, op, str(left), str(right)]
			}
		}

	match op:
		"+":
			return {"value": left + right}
		"-":
			return {"value": left - right}
		"*":
			return {"value": left * right}
		"/":
			if is_zero_approx(float(right)):
				return {"error": {"type": "ZeroDivisionError", "message": "ZeroDivisionError (Baris %d): Tidak bisa membagi angka dengan 0." % line_num}}
			var div_res: float = float(left) / float(right)
			if is_equal_approx(div_res, roundf(div_res)):
				return {"value": int(roundf(div_res))}
			return {"value": div_res}
		"//":
			if int(right) == 0:
				return {"error": {"type": "ZeroDivisionError", "message": "ZeroDivisionError (Baris %d): Tidak bisa membagi angka dengan 0." % line_num}}
			return {"value": int(floor(float(left) / float(right)))}
		"%":
			if int(right) == 0:
				return {"error": {"type": "ZeroDivisionError", "message": "ZeroDivisionError (Baris %d): Tidak bisa menghitung sisa bagi dengan 0." % line_num}}
			return {"value": int(left) % int(right)}

	return {"error": {"type": "SyntaxError", "message": "SyntaxError (Baris %d): Operator '%s' tidak dikenal." % [line_num, op]}}


static func _find_rightmost_keyword_op(s: String, kw: String) -> int:
	var depth := 0
	var in_s := false
	var in_d := false
	var best := -1
	var kw_len := kw.length()
	for i in range(s.length()):
		var c := s[i]
		if c == "'" and not in_d:
			in_s = not in_s
		elif c == "\"" and not in_s:
			in_d = not in_d
		elif not in_s and not in_d:
			if c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
			elif depth == 0 and i + kw_len <= s.length() and s.substr(i, kw_len) == kw:
				var prev_ok := (i > 0 and (s[i - 1] == " " or s[i - 1] == "\t" or s[i - 1] == ")"))
				var next_ok := (i + kw_len < s.length() and (s[i + kw_len] == " " or s[i + kw_len] == "\t" or s[i + kw_len] == "("))
				if prev_ok and next_ok:
					best = i
	return best


static func _find_rightmost_cmp_op(s: String) -> Dictionary:
	var depth := 0
	var in_s := false
	var in_d := false
	var best_idx := -1
	var best_op := ""
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "'" and not in_d:
			in_s = not in_s
		elif c == "\"" and not in_s:
			in_d = not in_d
		elif not in_s and not in_d:
			if c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
			elif depth == 0:
				if i + 1 < s.length():
					var two := s.substr(i, 2)
					if two == "==" or two == "!=" or two == "<=" or two == ">=":
						best_idx = i
						best_op = two
						i += 2
						continue
				if c == "<" or c == ">":
					best_idx = i
					best_op = c
		i += 1
	if best_idx != -1:
		return {"index": best_idx, "op": best_op}
	return {}


static func _find_top_level_assign(code: String) -> int:
	var in_s := false
	var in_d := false
	var depth := 0
	for i in range(code.length()):
		var c := code[i]
		if c == "'" and not in_d:
			in_s = not in_s
		elif c == "\"" and not in_s:
			in_d = not in_d
		elif not in_s and not in_d:
			if c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
			elif c == "=" and depth == 0:
				var prev := code[i - 1] if i > 0 else ""
				var next := code[i + 1] if i + 1 < code.length() else ""
				if prev != "=" and prev != "!" and prev != "<" and prev != ">" and next != "=":
					return i
	return -1


static func _parens_wrap_entire(s: String) -> bool:
	var depth := 0
	var in_s := false
	var in_d := false
	for i in range(s.length()):
		var c := s[i]
		if c == "'" and not in_d:
			in_s = not in_s
		elif c == "\"" and not in_s:
			in_d = not in_d
		elif not in_s and not in_d:
			if c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
				if depth == 0 and i < s.length() - 1:
					return false
	return depth == 0


static func _find_rightmost_top_op(s: String, ops: Array) -> int:
	var depth := 0
	var in_s := false
	var in_d := false
	var best := -1
	for i in range(s.length()):
		var c := s[i]
		if c == "'" and not in_d:
			in_s = not in_s
		elif c == "\"" and not in_s:
			in_d = not in_d
		elif not in_s and not in_d:
			if c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
			elif depth == 0 and ops.has(c):
				var prev_non_space := ""
				for j in range(i - 1, -1, -1):
					if s[j] != " " and s[j] != "\t":
						prev_non_space = s[j]
						break
				if prev_non_space != "+" and prev_non_space != "-" and prev_non_space != "*" and prev_non_space != "/" and prev_non_space != "%" and prev_non_space != "=" and prev_non_space != "<" and prev_non_space != ">":
					best = i
	return best


static func _find_rightmost_mul_op(s: String) -> Dictionary:
	var depth := 0
	var in_s := false
	var in_d := false
	var best_idx := -1
	var best_op := ""
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "'" and not in_d:
			in_s = not in_s
		elif c == "\"" and not in_s:
			in_d = not in_d
		elif not in_s and not in_d:
			if c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
			elif depth == 0:
				if i + 1 < s.length() and s.substr(i, 2) == "//":
					best_idx = i
					best_op = "//"
					i += 2
					continue
				elif c == "*" or c == "/" or c == "%":
					best_idx = i
					best_op = c
		i += 1
	if best_idx != -1:
		return {"index": best_idx, "op": best_op}
	return {}


static func _split_top_level_commas(s: String) -> Array[String]:
	var res: Array[String] = []
	var depth := 0
	var in_s := false
	var in_d := false
	var start := 0
	for i in range(s.length()):
		var c := s[i]
		if c == "'" and not in_d:
			in_s = not in_s
		elif c == "\"" and not in_s:
			in_d = not in_d
		elif not in_s and not in_d:
			if c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
			elif c == "," and depth == 0:
				res.append(s.substr(start, i - start))
				start = i + 1
	res.append(s.substr(start))
	return res


static func _is_valid_identifier(name: String) -> bool:
	if name.is_empty():
		return false
	var first := name.unicode_at(0)
	var is_alpha := (first >= 65 and first <= 90) or (first >= 97 and first <= 122) or first == 95
	if not is_alpha:
		return false
	for i in range(1, name.length()):
		var c := name.unicode_at(i)
		var ok := (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
		if not ok:
			return false
	return true


static func _format_py_value(v) -> String:
	if typeof(v) == TYPE_BOOL:
		return "True" if v else "False"
	return str(v)


static func _suggest_identifier(target: String, candidates: Array[String]) -> String:
	var best := ""
	var best_dist := 999
	for cand in candidates:
		var d := _levenshtein(target.to_lower(), cand.to_lower())
		if d < best_dist and d <= 3:
			best_dist = d
			best = cand
	return best


static func _levenshtein(a: String, b: String) -> int:
	var n := a.length()
	var m := b.length()
	if n == 0:
		return m
	if m == 0:
		return n
	var dp: Array = []
	for i in range(n + 1):
		var row: Array[int] = []
		row.resize(m + 1)
		row[0] = i
		dp.append(row)
	for j in range(m + 1):
		dp[0][j] = j
	for i in range(1, n + 1):
		for j in range(1, m + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			dp[i][j] = mini(mini(dp[i - 1][j] + 1, dp[i][j - 1] + 1), dp[i - 1][j - 1] + cost)
	return dp[n][m]
