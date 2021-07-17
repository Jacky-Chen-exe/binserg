/*******************************************************************************
BINSCATTER  
Date: 17-JUL-2021 
Authors: Matias Cattaneo, Richard K. Crump, Max H. Farrell, Yingjie Feng
*******************************************************************************/
** hlp2winpdf, cdn(binsreg) replace
** hlp2winpdf, cdn(binsqreg) replace
** hlp2winpdf, cdn(binslogit) replace
** hlp2winpdf, cdn(binsprobit) replace
** hlp2winpdf, cdn(binstest) replace
** hlp2winpdf, cdn(binspwc) replace
** hlp2winpdf, cdn(binsregselect) replace
*******************************************************************************/
** net install binsreg, from(https://sites.google.com/site/nppackages/binsreg/stata) replace
********************************************************************************
clear all
set more off
set linesize 90

********************************************************************************
** Binsreg Sim Data: Generation / COMMENTED OUT
********************************************************************************
/*

local n=1000
set obs `n'
set seed 1234

* X-var
gen x=runiform()
* True fun
gen mu=4*x-2+0.8*exp(-256*(x-0.5)^2)
* A continuous covariate
gen w=runiform()*2-1
* A binary covariate
gen t=(runiform()>0.5)
* error term
gen eps=rnormal()
* A cluster id, only for illustration purpose
gen id=ceil(_n/2)
* Y-var
gen y=mu+w+t+eps
* A binary outcome
gen d=(runiform()<=x/(.5+x))

keep y x w t d id 
saveold binsreg_simdata, replace version(13)

*/

********************************************************************************
** Binscatter Sim Data: Setup and summary stats
********************************************************************************
sjlog using output/binsreg_out0, replace
use binsreg_simdata, clear
sum
sjlog close, replace

********************************************************************************
** BINSREG: least squares regression
********************************************************************************
* Default syntax
sjlog using output/binsreg_out1, replace
binsreg y x w
sjlog close, replace

graph export output/binsreg_fig1.pdf, replace

* Evaluate the estimated function at median of w rather than the mean
sjlog using output/binsreg_out2, replace
binsreg y x w, at(median)
sjlog close, replace

* Add a factor variable, evaluate the estimated function at w=0.2 and t=1 saved in another file
sjlog using output/binsreg_out3, replace
tempfile evalcovar
preserve
clear
set obs 1
gen w=0.2
gen t=1
save `evalcovar', replace
restore
binsreg y x w i.t, at(`evalcovar')
sjlog close, replace

* Setting quantile-spaced bins to J=20, add a linear fit
sjlog using output/binsreg_out4, replace
binsreg y x w, nbins(20) polyreg(1)
sjlog close, replace

* Adding lines, ci, cb, polyreg
sjlog using output/binsreg_out5, replace
qui binsreg y x w, nbins(20) dots(0,0) line(3,3)
qui binsreg y x w, nbins(20) dots(0,0) line(3,3) ci(3,3)
qui binsreg y x w, nbins(20) dots(0,0) line(3,3) ci(3,3) cb(3,3)
qui binsreg y x w, nbins(20) dots(0,0) line(3,3) ci(3,3) cb(3,3) polyreg(4)
sjlog close, replace

binsreg y x w, nbins(20) dots(0,0) line(3,3)
graph export output/binsreg_fig2a.pdf, replace
binsreg y x w, nbins(20) dots(0,0) line(3,3) ci(3,3)
graph export output/binsreg_fig2b.pdf, replace
binsreg y x w, nbins(20) dots(0,0) line(3,3) ci(3,3) cb(3,3)
graph export output/binsreg_fig2c.pdf, replace
binsreg y x w, nbins(20) dots(0,0) line(3,3) ci(3,3) cb(3,3) polyreg(4)
graph export output/binsreg_fig2d.pdf, replace

* VCE option, factor vars, twoway options, graph data saving  
sjlog using output/binsreg_out6, replace
binsreg y x w i.t, dots(0,0) line(3,3) ci(3,3) cb(3,3) polyreg(4) ///
                   vce(cluster id) savedata(output/graphdat) replace ///
				   title("Binned Scatter Plot") 
sjlog close, replace

* CI and CB: alternative formula for standard errors (nonparametric component only)
sjlog using output/binsreg_out7, replace
binsreg y x w i.t, dots(0,0) line(3,3) ci(3,3) cb(3,3) polyreg(4) ///
                   vce(cluster id) asyvar(on) title("Binned Scatter Plot") 
sjlog close, replace

* Comparision by groups
sjlog using output/binsreg_out8, replace
binsreg y x w, by(t) dots(0,0) line(3,3) cb(3,3) ///
               bycolors(blue red) bysymbols(O T) 
sjlog close, replace
graph export output/binsreg_fig3.pdf, replace

* Use reghdfe command to add fixed effects instead of using "i."
* note: need to install reghdfe first
sjlog using output/binsreg_out9, replace
binsreg y x w, absorb(t) dots(0,0) line(3,3) ci(3,3) cb(3,3) polyreg(4)
sjlog close, replace

* Shut down checks to speed computation
sjlog using output/binsreg_out10, replace
qui binsreg y x w, masspoints(off)
sjlog close, replace

* Furthermore, use Gtools package to speed computation
* note: need to install Gtools first
sjlog using output/binsreg_out11, replace
qui binsreg y x w, masspoints(off) usegtools(on)
sjlog close, replace


********************************************************************************
** BINSQREG: quantile regression
********************************************************************************

* 0.25 quantile
sjlog using output/binsreg_out12, replace
binsqreg y x w, quantile(0.25)
sjlog close, replace

* use bootstrap-based VCE
sjlog using output/binsreg_out13, replace
binsqreg y x w, quantile(0.25) ci(3 3) vce(bootstrap, reps(100))
sjlog close, replace

* estimate 0.25 and 0.75 quantiles and combine them with the results from binsreg 
sjlog using output/binsreg_out14, replace
tempfile file_q25 file_q75 file_reg
preserve
binsqreg y x, quantile(0.25) line(3 3) savedata(`file_q25')
binsqreg y x, quantile(0.75) line(3 3) savedata(`file_q75')
binsreg y x, line(3 3) cb(3 3) savedata(`file_reg')
use `file_reg', clear
append using `file_q25' `file_q75', generate(source)
twoway (scatter dots_fit dots_x if source==0, mcolor(navy)) ///
       (line line_fit line_x if source==0, sort lcolor(navy)) ///
	   (rarea CB_l CB_r CB_x if source==0, sort fcolor(navy%50) lcolor(none%0) fintensity(50)) ///
	   (line line_fit line_x if source==1, sort) ///
	   (line line_fit line_x if source==2, sort), ///
	   ytitle(Y) xtitle(X) title(Binscatter Plot) ///
	   legend(order(1 "E[Y|X]" 2 "E[Y|X]" 3 "Conf. Band for E[Y|X]" 4 "0.25 quantile" 5 "0.75 quantile"))
restore
sjlog close, replace
graph export output/binsreg_fig4.pdf, replace

********************************************************************************
** BINSLOGIT: logistic regression
********************************************************************************

* Basic syntax
sjlog using output/binsreg_out15, replace
binslogit d x w
sjlog close, replace

* Plot the function in the inverse link (logistic) function rather than the 
* conditional probability
sjlog using output/binsreg_out16, replace
binslogit d x w, nolink
sjlog close, replace


********************************************************************************
** BINSTEST
********************************************************************************

** Least Squares Regression (Default)
* Basic syntax: linear?
sjlog using output/binsreg_out17, replace
binstest y x w, testmodelpoly(1)
sjlog close, replace

* Alternative: save parametric fit in another file, and/or use lp metric rather than sup
* If not available, first create empty file with grid points using binsregselect
sjlog using output/binsreg_out18, replace
qui binsregselect y x w, simsgrid(30) savegrid(output/parfitval) replace
qui reg y x w
use output/parfitval, clear
predict binsreg_fit_lm
save output/parfitval, replace
use binsreg_simdata, clear
binstest y x w, testmodelparfit(output/parfitval) lp(2)
sjlog close, replace

* Shape restriction test: increasing?
sjlog using output/binsreg_out19, replace
binstest y x w, deriv(1) nbins(20) testshaper(0)
sjlog close, replace

* Test many things simultaneously
sjlog using output/binsreg_out20, replace
binstest y x w, nbins(20) testshaper(-2 0) testshapel(4) testmodelpoly(1) ///
                   nsims(1000) simsgrid(30)
sjlog close, replace

** Quantile Regression
* Median regression: linear?
sjlog using output/binsreg_out21, replace
binstest y x w, estmethod(qreg 0.5) testmodelpoly(1)
sjlog close, replace

** Logitistic Regression
* Shape restriction test: increasing?
sjlog using output/binsreg_out22, replace
binstest d x w, estmethod(logit) deriv(1) nbins(20) testshaper(0)
sjlog close, replace


********************************************************************************
** BINSPWC: pairwise group comparison
********************************************************************************
* Basic syntax
sjlog using output/binsreg_out23, replace
binspwc y x w, by(t)
sjlog close, replace

* Compare quantile regression functions
sjlog using output/binsreg_out24, replace
binspwc y x w, by(t) estmethod(qreg 0.4)
sjlog close, replace


********************************************************************************
** BINSREGSELECT
********************************************************************************
* Basic syntax
sjlog using output/binsreg_out25, replace
binsregselect y x w
sjlog close, replace

* J ROT specified manually and require evenly-spaced binning
sjlog using output/binsreg_out26, replace
binsregselect y x w, nbinsrot(20) binspos(es)
sjlog close, replace

* Save grid for prediction purpose
sjlog using output/binsreg_out27, replace
binsregselect y x w, simsgrid(30) savegrid(output/parfitval) replace
sjlog close, replace

* Extrapolating the optimal number of bins to the full sample
sjlog using output/binsreg_out28, replace
binsregselect y x w if t==0, useeffn(1000)
sjlog close, replace

* Use a random subsample to select the number of bins for the full sample
sjlog using output/binsreg_out29, replace
binsregselect y x w, randcut(0.3)
sjlog close, replace

