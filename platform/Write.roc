import Host

Write := [].{
    write! : Str => {}
    write! = |s| Host.write_string!(s)
}
