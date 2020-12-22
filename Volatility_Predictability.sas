libname saslib 'C:\Users\flora\Desktop\470\assignment2';
%let ym=year(date)*100+month(date);
data saslib.daily;
set saslib.Factors_daily_new;
mktrf=log(1+mktrf);
ym=&ym; mktrf_lag=lag(mktrf);
mktvar=mktrf**2;
keep date mktrf ym mktrf_lag mktvar;run;
data saslib.daily;
set saslib.daily; by ym;
if first.ym then cor=0; else cor=mktrf*mktrf_lag; run;
proc sql; create table saslib.rv as select ym,sum(mktrf) as mktrf_m, sum(mktvar)+2*sum(cor) as var, sqrt(12*(calculated var)) as mktstd from saslib.daily group by
ym;
quit;
data saslib.vxo;
set saslib.vxo_daily;
ym=&ym;run;
data saslib.vxo;
set saslib.vxo;by ym;
if last.ym then ;else delete; run;
proc sql; create table saslib.rv_vxo as select a.*,b.* from saslib.rv as a, saslib.vxo as b where a.ym=b.ym;
quit;
proc univariate data=saslib.rv_vxo;
histogram mktstd vxo/midpoints=(0.05 to 1 by 0.05); run;
ods graphics on;
proc arima data=saslib.rv_vxo plots=series(all);
identify var=mktstd crosscorr=vxo;
estimate input=(1$vxo) p=1 method=ml;
forecast lead=0 id=ym out=saslib.rv_vxo_pre; quit;
ods graphics off;
proc sql; create table temp0 as select *,mean(mktstd) as m_rv from saslib.rv_vxo_pre; quit;
proc sql; create table saslib.rv_vxo_pre1 as select mean(abs(residual)) as
mad,100*mean(abs(residual/mktstd)) as mape,mean((residual**2)) as mse1,
mean(((mktstd-m_rv)**2)) as mse0, (1-(calculated mse1)/(calculated mse0)) as R2 from
temp0; quit;
ods graphics on;
proc arima data=saslib.rv_vxo plots=serise(all);
identify var=vxo crosscorr=mktstd;
estimate input=(1$mktstd) p=1 method=ml;
forecast lead=0 id=ym out=saslib.vxo_rv_pre;quit;
ods graphics off;
proc sql; create table temp1 as select *,mean(vxo) as m_vxo from saslib.vxo_rv_pre; quit;
proc sql; create table saslib.rv_vxo_pre2 as select mean(abs(residual)) as
mad,100*mean(abs(residual/vxo)) as mape,mean((residual**2)) as mse1, mean(((vxom_vxo)**2)) as mse0, (1-(calculated mse1)/(calculated mse0)) as R2 from temp1; quit;
/*partii*/
proc univariate data=saslib.Rv_vxo_pre;
var forecast;
histogram; run;
data saslib.rv_vxo_1;
set saslib.rv_vxo;
mktrf_m=exp(mktrf_m)-1; run;
data saslib.Factors_monthly;
set saslib.Factors_monthly_new;
mkt=mktrf+rf; ym=&ym; keep ym mktrf rf mkt; run;
option mprint;
%macro loop_statistic(vol_start,vol_end,fear);
proc sql; create table market as select 0 as flag, 12*mean(log(1+mkt)) as return_ann,
sqrt(12)*std(log(1+mkt)) as std_ann, (calculated std_ann**2) as var_ann,
sqrt(12)*mean(log(1+mkt-rf))/std(log(1+mkt-rf)) as sharp_ratio,((calculated return_ann)-
0.5*&fear*(calculated var_ann)) as utility from saslib.Factors_monthly as a,
saslib.Rv_vxo_pre as b where a.ym=b.ym;
quit;
%do i=&vol_start %to &vol_end;
proc sql; create table combine as select a.*,b.forecast, &i/100/b.forecast as wet,log(((calculated
wet)*mkt+(1-calculated wet)*rf)+1) as rp,log(((calculated wet)*mkt-(calculated
wet)*rf)+1) as rp_rf from saslib.Factors_monthly as a, saslib.Rv_vxo_pre as b where
a.ym=b.ym;
quit;
proc sql; create table loop as select &i as flag,12*mean(rp) as return_ann, sqrt(12)*std(rp) as
std_ann, (calculated std_ann**2) as var_ann, sqrt(12)*mean(rp_rf)/std(rp_rf) as
sharp_ratio,((calculated return_ann)-0.5*&fear*(calculated var_ann)) as utility from
combine;
quit;
proc append base=market data=loop; run;
%end;
%mend loop_statistic;
%loop_statistic(4,16,4);
proc univariate data=combine;
var wet;
histogram; run;
proc sgplot data=market;
where flag>0;
series x=flag y=std_ann;
series x=flag y=sharp_ratio;
series x=flag y=utility; run;
/*Partiii*/
proc sql; create table saslib.part3 as select a.*,b.vxo from saslib.Factors_monthly as a,
saslib.vxo as b where a.ym=b.ym;
quit;
ods graphics on;
proc arima data=saslib.part3 plots=serise(all);
identify var=mktrf crosscorr=vxo;
estimate input=(1$vxo) method=ml;
forecast lead=0 id=ym out=saslib.part3_pre; quit;
ods graphics off;
proc sgplot data=saslib.rv_vxo;
series x=ym y=vxo;
series x=ym y=mktstd; run;
proc sql; create table saslib.part3_2 as select a.*,b.vxo,b.mktstd,vxo-mktstd as fear from
saslib.Factors_monthly as a, saslib.rv_vxo as b where a.ym=b.ym;
quit;
proc arima data=saslib.part3_2 plots=serise(all);
identify var=mktrf crosscorr=fear;
estimate input=(1$fear) method=ml; quit;
