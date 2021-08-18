# single-gpu-passthrough

### Hyper-V Elightenments
```conf
<vpindex state="on"/>
<synic state="on"/>
<stimer state="on"/>
<reset state="on"/>
<vendor_id state="on" value="whatever_value"/>
<frequencies state="on"/>
<kvm>
  <hidden state="on"/>
</kvm>
```

### Enabling SMT Performance (for AMD Ryzen CPUs)
```conf
<feature policy="require" name="topoext"/>
```
