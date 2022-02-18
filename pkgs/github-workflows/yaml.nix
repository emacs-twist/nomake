{ json2yaml
, runCommandLocal
}:
name: data:
runCommandLocal name {
  buildInputs = [
    json2yaml
  ];
  text = builtins.toJSON data;
  passAsFile = [ "text" ];
}
''
  if [[ -e "$textPath" ]]
  then
    json2yaml < "$textPath" > $out
  else
    echo -n "$text" | json2yaml > $out
  fi
''
