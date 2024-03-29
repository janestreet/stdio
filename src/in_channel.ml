open! Base

type t = Stdlib.in_channel

let equal (t1 : t) t2 = phys_equal t1 t2
let seek = Stdlib.LargeFile.seek_in
let pos = Stdlib.LargeFile.pos_in
let length = Stdlib.LargeFile.in_channel_length
let stdin = Stdlib.stdin

let create ?(binary = true) file =
  let flags = [ Open_rdonly ] in
  let flags = if binary then Open_binary :: flags else flags in
  Stdlib.open_in_gen flags 0o000 file
;;

let close = Stdlib.close_in
let with_file ?binary file ~f = Exn.protectx (create ?binary file) ~f ~finally:close

let may_eof f =
  try Some (f ()) with
  | End_of_file -> None
;;

let input t ~buf ~pos ~len = Stdlib.input t buf pos len
let really_input t ~buf ~pos ~len = may_eof (fun () -> Stdlib.really_input t buf pos len)
let really_input_exn t ~buf ~pos ~len = Stdlib.really_input t buf pos len
let input_byte t = may_eof (fun () -> Stdlib.input_byte t)
let input_char t = may_eof (fun () -> Stdlib.input_char t)
let input_binary_int t = may_eof (fun () -> Stdlib.input_binary_int t)
let unsafe_input_value t = may_eof (fun () -> Stdlib.input_value t)
let input_buffer t buf ~len = may_eof (fun () -> Stdlib.Buffer.add_channel buf t len)
let set_binary_mode = Stdlib.set_binary_mode_in

let input_all t =
  (* We use 65536 because that is the size of OCaml's IO buffers. *)
  let chunk_size = 65536 in
  let buffer = Buffer.create chunk_size in
  let rec loop () =
    Stdlib.Buffer.add_channel buffer t chunk_size;
    loop ()
  in
  try loop () with
  | End_of_file -> Buffer.contents buffer
;;

let trim ~fix_win_eol line =
  if fix_win_eol
  then (
    let len = String.length line in
    if len > 0 && Char.equal (String.get line (len - 1)) '\r'
    then String.sub line ~pos:0 ~len:(len - 1)
    else line)
  else line
;;

let input_line ?(fix_win_eol = true) t =
  match may_eof (fun () -> Stdlib.input_line t) with
  | None -> None
  | Some line -> Some (trim ~fix_win_eol line)
;;

let input_line_exn ?(fix_win_eol = true) t =
  let line = Stdlib.input_line t in
  trim ~fix_win_eol line
;;

let fold_lines ?fix_win_eol t ~init ~f =
  let rec loop ac =
    match input_line ?fix_win_eol t with
    | None -> ac
    | Some line -> loop (f ac line)
  in
  loop init
;;

let input_lines ?fix_win_eol t =
  List.rev (fold_lines ?fix_win_eol t ~init:[] ~f:(fun lines line -> line :: lines))
;;

let iter_lines ?fix_win_eol t ~f =
  fold_lines ?fix_win_eol t ~init:() ~f:(fun () line -> f line)
;;

let read_lines ?fix_win_eol fname = with_file fname ~f:(input_lines ?fix_win_eol)
let read_all fname = with_file fname ~f:input_all
