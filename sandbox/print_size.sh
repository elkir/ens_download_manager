cat mars_01_one_ensemble.list_cost | sed -n "s/^size=\([0-9]*\);/\1/p" | numfmt --to=iec        
