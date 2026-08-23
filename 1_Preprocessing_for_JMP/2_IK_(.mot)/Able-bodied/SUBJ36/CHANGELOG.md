# Changelog

## v.1.5.0 - 2026-01-26

#####Step 1 
Updating joint ranges based on RajagopalLaiUhlrich2023.osim

<range> of pelvis_rotation changed from -1.57079633 1.57079633 to -6.2831853071795862 6.2831853071795862
<range> of pelvis_tx changed from -5 5 to -50 50
<range> of knee_angle_r, knee_angle_l changed from 0 2.0944 to 0 2.4434609527920599
<range> of ankle_angle_r, ankle_angle_l changed from -0.8727 0.6981 to -0.8727 0.8727
<range> of mtp_angle_r, mtp_angle_l changed from -0.52359878 0.52359878 to -0.78539816339744828 0.52359878

#####Step 2
Updating knee joint definitions based on RajagopalLaiUhlrich2023.osim

<translation> of <PhysicalOffsetFrame name="femur_r_offset"> changed
from -0.00809 -0.40796 -0.00275 to -0.0045 -0.4096 -0.00175

<orientation> of of <PhysicalOffsetFrame name="femur_r_offset"> changed
from -0.070770028484130998 0 0.12461632679406499 to -0.070773673 0.0000036732 0.124616326

<translation> of <PhysicalOffsetFrame name="femur_l_offset"> changed 
from -0.00809 -0.40796 0.00275 to -0.0045 -0.4096 0.00175

<orientation> of of <PhysicalOffsetFrame name="femur_l_offset"> changed
from 0.070770028484130998 0 0.12461632679406499 to 0.070773673 0.0000036732 0.124616326

<SimmSpline name="function"> of <TransformAxis name="rotation3"> of <CustomJoint name="knee_r">  
+ internal rotation of tibia relative to femur (both RNCL2025 and RajagopalLaiUhlrich2023)
changed to
<PolynomialFunction name="function">
<coefficients>0.025165762727423002 -0.16948005139054001 0.36949934868824902 -4.4303583088363053e-08</coefficients>

<SimmSpline name="function"> of <TransformAxis name="rotation3"> of <CustomJoint name="knee_l">  
+ internal rotation of tibia relative to femur (RCNL2025)
+ external rotation of tibia relative to femur (RajagopalLaiUhlrich2023)
changed to
<PolynomialFunction name="function">
<coefficients>0.025165762727423002 -0.16948005139054001 0.36949934868824902 -4.4303583088363053e-08</coefficients> 
(opposite signs to RajagopalLaiUhlrich2023)

<SimmSpline name="function"> of <TransformAxis name="translation1"> of <CustomJoint name="knee_r">  
+ superior translation of tibia relative to femur (both RNCL2025 and RajagopalLaiUhlrich2023)
changed to
<PolynomialFunction name="function">
<coefficients>-0.00057968780523386836 0.0050797657456260002 -0.011442375726364 0.0039369086688440004 -2.5163503832135249e-05</coefficients>

<SimmSpline name="function"> of <TransformAxis name="translation1"> of <CustomJoint name="knee_l">  
+ superior translation of tibia relative to femur (both RNCL2025 and RajagopalLaiUhlrich2023)
changed to
<PolynomialFunction name="function">
<coefficients>-0.00057968780523386836 0.0050797657456260002 -0.011442375726364 0.0039369086688440004 -2.5163503832135249e-05</coefficients>

<SimmSpline name="function"> of <TransformAxis name="translation2"> of <CustomJoint name="knee_r">  
+ anterior translation of tibia relative to femur (both RNCL2025 and RajagopalLaiUhlrich2023)
changed to
<PolynomialFunction name="function">
<coefficients>0.001208086889206 -0.004453611224706 0.00061164940729817395 0.006265429606387 -1.461912533723326e-05</coefficients>

<SimmSpline name="function"> of <TransformAxis name="translation2"> of <CustomJoint name="knee_l">  
+ posterior translation of tibia relative to femur (both RNCL2025 and RajagopalLaiUhlrich2023)
changed to
<PolynomialFunction name="function">
<coefficients>-0.001208086889206 0.004453611224706 -0.00061164940729817395 -0.006265429606387 1.461912533723326e-05</coefficients>

<Constant name="function"> of <TransformAxis name="translation3"> of <CustomJoint name="knee_r">  
+ medial translation of tibia relative to femur (both RNCL2025 and RajagopalLaiUhlrich2023)
changed to
<PolynomialFunction name="function">
<coefficients>0.00015904478788503811 -0.001015149915669 0.001817510974968 2.6414266451992301e-05 -7.7465635324718924e-07</coefficients>

<Constant name="function"> of <TransformAxis name="translation3"> of <CustomJoint name="knee_l">  
+ medial translation of tibia relative to femur (both RNCL2025 and RajagopalLaiUhlrich2023)
changed to
<PolynomialFunction name="function">
<coefficients>0.00015904478788503811 -0.001015149915669 0.001817510974968 2.6414266451992301e-05 -7.7465635324718924e-07</coefficients>

#####Step 3
Updating muscle geometry and properties based on RajagopalLaiUhlrich2023.osim

<WrapCylinder name="Gastroc_at_condyles_r"> replaced by
<WrapCylinder name="GasLat_at_condyles_r">
<WrapCylinder name="GasMed_at_condyles_r">

<wrap_object> of <Millard2012EquilibriumMuscle name="gaslat_r"> changed to <WrapCylinder name="GasLat_at_condyles_r">
<wrap_object> of <Millard2012EquilibriumMuscle name="gasmed_r"> changed to <WrapCylinder name="GasMed_at_condyles_r">

<WrapCylinder name="Gastroc_at_condyles_l"> replaced by
<WrapCylinder name="GasLat_at_condyles_l">
<WrapCylinder name="GasMed_at_condyles_l">

<wrap_object> of <Millard2012EquilibriumMuscle name="gaslat_l"> changed to <WrapCylinder name="GasLat_at_condyles_l">
<wrap_object> of <Millard2012EquilibriumMuscle name="gasmed_l"> changed to <WrapCylinder name="GasMed_at_condyles_l">

<WrapCylinder name="KnExtVL_at_fem_r"> added
<wrap_object> of <Millard2012EquilibriumMuscle name="vaslat_r"> changed to <WrapCylinder name="KnExtVL_at_fem_r">

<WrapCylinder name="KnExtVL_at_fem_l"> added
<wrap_object> of <Millard2012EquilibriumMuscle name="vaslat_l"> changed to <WrapCylinder name="KnExtVL_at_fem_l">

<radius> of <WrapCylinder name="GasMed_at_shank_r"> changed from 0.055 to 0.059
<radius> of <WrapCylinder name="SM_at_condyles_r"> changed from 0.0352 to 0.0345
<translation> of <WrapCylinder name="BF_at_gastroc_r"> changed from -0.058 -0.06 0 to -0.039 -0.06 0
<radius> of <WrapCylinder name="BF_at_gastroc_r"> changed from 0.03 to 0.029

<radius> of <WrapCylinder name="GasMed_at_shank_l"> changed from 0.055 to 0.059
<radius> of <WrapCylinder name="SM_at_condyles_l"> changed from 0.0352 to 0.0345
<translation> of <WrapCylinder name="BF_at_gastroc_l"> changed from -0.058 -0.06 0 to -0.039 -0.06 0
<radius> of <WrapCylinder name="BF_at_gastroc_l"> changed from 0.03 to 0.029

<fiber_damping> of all muscles changed from 0.01 to 0.01

muscle		<optimal_fiber_length> was	<optimal_fiber_length> updated		<tendon_slack_length> was	<tendon_slack_length> updated
addbrev_r	0.1031				0.1031					0.035450291324676003		0.035450291327550627
addlong_r	0.1082				0.1082					0.13179936334202599		0.13179936338498821
addmagDist_r	0.1772				0.1772					0.087380695461772698		0.087380695368053041
admagIsch_r	0.1562				0.1562					0.216343023454343		0.21634302327343438
addmagMid_r	0.1377				0.1377					0.046627699907046398		0.046627699859408046
addmagProx_r	0.1056				0.1056					0.0403240979232675		0.040324097914847909
bflh_r		0.0976				0.0976					0.32522664751645702		0.3325
bfsh_r		0.1103				0.1103					0.105817218589115		0.10581791424960163
edl_r		0.0693				0.0693					0.36887524546522499		0.36887524543019445
ehl_r		0.0748				0.0748					0.32679527953718701		0.32679527950110016
fdl_r		0.0446				0.0446					0.37877285679384198		0.37877285680181139
fhl_r		0.0527				0.0527					0.354339676836818		0.35433967685061135
gaslat_r	0.0588				0.069					0.376070169933794		0.374
gasmed_r	0.051				0.059					0.39871633262642903		0.387
glmax1_r	0.147				0.147					0.048840888946285299		0.0873
glmax2_r	0.157				0.157					0.067887151179264096		0.109
glmax3_r	0.167				0.167					0.069716605884370703		0.103
glmed1_r	0.073				0.0765					0.055816831943655401		0.0585
glmed2_r	0.073				0.084					0.065248811199234799		0.07545
glmed3_r	0.073				0.0781					0.045232843601358298		0.0484
glmin1_r	0.068				0.0813					0.016137782374970301		0.0193
glmin2_r	0.056				0.0687					0.026099052409878899		0.03202
glmin3_r	0.038				0.0353					0.0508725			0.0472
grac_r		0.2278				0.2278					0.17201381056437301		0.1720144422091848
iliacus_r	0.1066				0.1066					0.096120708398325802		0.096120708483077522
perbrev_r	0.0454				0.0454					0.147527533956538		0.14752753396176685
perlong_r	0.0508				0.0508					0.33222076263797801		0.33222076264689515
piri_r		0.026				0.026					0.114906238342785		0.11490623835345963
psoas_r		0.1169				0.1169					0.099543165855508306		0.099543165901858605
recfem_r	0.0759				0.0759					0.448493537399412		0.4504
sart_r		0.403				0.403					0.123999830194402		0.124
semimem_r	0.069				0.086					0.34758597953321402		0.335
semiten_r	0.193				0.193					0.24719894503751		0.24720046213967523
soleus_r	0.044				0.044					0.27675587237597599		0.28135
tfl_r		0.095				0.09315					0.44949705380542798		0.44075
tibant_r	0.0683				0.0683					0.24046102640936701		0.2404610263707892
tibpost_r	0.0378				0.0378					0.280779613883954		0.28077961389296008	
vasint_r	0.0993				0.117					0.20221067034576301		0.205
vaslat_r	0.0994				0.117					0.22060128483460301		0.221
vasmed_r	0.0968				0.11					0.19990427084231699		0.208
addbrev_l	0.1031				0.1031					0.035450291324676003		0.035450291326672399
addlong_l	0.1082				0.1082					0.13179936334202599		0.13179936336729978
addmagDist_l	0.1772				0.1772					0.087380695461772698		0.087380695408902295
admagIsch_l	0.1562				0.1562					0.216343023454343		0.21634302335191261
addmagMid_l	0.1377				0.1377					0.046627699907046398		0.046627699880459048
addmagProx_l	0.1056				0.1056					0.0403240979232675		0.0403240979189338
bflh_l		0.0976				0.0976					0.32522664751645702		0.3325
bfsh_l		0.1103				0.1103					0.105817218589115		0.105817693073679
edl_l		0.0693				0.0693					0.36887524546522499		0.3688752454557237
ehl_l		0.0748				0.0748					0.32679527953718701		0.32679527952739923
fdl_l		0.0446				0.0446					0.37877285679384198		0.37877285679600353
fhl_l		0.0527				0.0527					0.354339676836818		0.35433967685061135
gaslat_l	0.0588				0.069					0.376070169933794		0.374
gasmed_l	0.051				0.059					0.39871633262642903		0.387
glmax1_l	0.147				0.147					0.048840888946285299		0.0873
glmax2_l	0.157				0.157					0.067887151179264096		0.109
glmax3_l	0.167				0.167					0.069716605884370703		0.103
glmed1_l	0.073				0.0765					0.055816831943655401		0.0585
glmed2_l	0.073				0.084					0.065248811199234799		0.07545
glmed3_l	0.073				0.0781					0.045232843601358298		0.0484
glmin1_l	0.068				0.0813					0.016137782374970301		0.0193
glmin2_l	0.056				0.0687					0.026099052409878899		0.03202
glmin3_l	0.038				0.0353					0.0508725			0.0472
grac_l		0.2278				0.2278					0.17201381056437301		0.17201424138464527
iliacus_l	0.1066				0.1066					0.096120708398325802		0.096120708446520403
perbrev_l	0.0454				0.0454					0.147527533956538		0.14752753396176685
perlong_l	0.0508				0.0508					0.33222076263797801		0.33222076264039657
piri_l		0.026				0.026					0.114906238342785		0.11490623834834697
psoas_l		0.1169				0.1169					0.099543165855508306		0.099543165881948059
recfem_l	0.0759				0.0759					0.448493537399412		0.4504
sart_l		0.403				0.403					0.123999830194402		0.124
semimem_l	0.069				0.086					0.34758597953321402		0.335
semiten_l	0.193				0.193					0.24719894503751		0.24719997981456862
soleus_l	0.044				0.044					0.27675587237597599		0.28135
tfl_l		0.095				0.09315					0.44949705380542798		0.44075
tibant_l	0.0683				0.0683					0.24046102640936701		0.24046102639890365
tibpost_l	0.0378				0.0378					0.280779613883954		0.28077961389296008	
vasint_l	0.0993				0.117					0.20221067034576301		0.205
vaslat_l	0.0994				0.117					0.22060128483460301		0.221
vasmed_r	0.0968				0.11					0.19990427084231699		0.208

<location> of <PathPoint name="bflh_r-P2"> changed to -0.03436 -0.03648 0.03618
<location> of <PathPoint name="bflh_r-P3"> changed to -0.02704 -0.05008 0.03476
<location> of <PathPoint name="bfsh_r-P2"> changed to -0.02866 -0.03284 0.03204
<location> of <PathPoint name="gaslat_r-P1"> changed to 0.002 -0.381 0.02059
<location> of <PathPoint name="gasmed_r-P1"> changed to 0.006 -0.385 -0.022
<location> of <PathPoint name="glmed1_r-P1"> changed to -0.049 0.026 0.115
<location> of <PathPoint name="glmed1_r-P2"> changed to -0.014 -0.018 0.059
<location> of <PathPoint name="glmed2_r-P1"> changed to -0.085 0.055 0.082
<location> of <PathPoint name="glmed2_r-P2"> changed to -0.022 -0.01 0.056
<location> of <PathPoint name="glmed3_r-P1"> changed to -0.100 0.016 0.064
<location> of <PathPoint name="glmin1_r-P1"> changed to -0.030 0 0.118
<location> of <PathPoint name="glmin1_r-P2"> changed to 0.005 -0.015 0.056
<location> of <PathPoint name="glmin2_r-P1"> changed to -0.0616 0.01 0.101
<location> of <PathPoint name="glmin2_r-P2"> changed to 0.004 -0.009 0.052
<location> of <PathPoint name="glmin3_r-P2"> changed to -0.004 -0.001 0.051
<location> of <PathPoint name="semimem_r-P2"> changed to -0.027 -0.041 -0.0196
<location> of <PathPoint name="tfl_r-P1"> changed to -0.02 0.011 0.129
<location> of <PathPoint name="bflh_l-P2"> changed to -0.03436 -0.03648 -0.03618
<location> of <PathPoint name="bflh_l-P3"> changed to -0.027046 -0.05008 -0.03476
<location> of <PathPoint name="bfsh_l-P2"> changed to -0.02866 -0.03284 -0.03204
<location> of <PathPoint name="gaslat_l-P1"> changed to 0.002 -0.381 -0.02059
<location> of <PathPoint name="gasmed_l-P1"> changed to 0.006 -0.385 0.022
<location> of <PathPoint name="glmed1_l-P1"> changed to -0.049 0.026 -0.115
<location> of <PathPoint name="glmed1_l-P2"> changed to -0.014 -0.018 -0.059
<location> of <PathPoint name="glmed2_l-P1"> changed to -0.085 0.055 -0.082
<location> of <PathPoint name="glmed2_l-P2"> changed to -0.022 -0.01 -0.056
<location> of <PathPoint name="glmed3_l-P1"> changed to -0.10 0.016 -0.064
<location> of <PathPoint name="glmin1_l-P1"> changed to -0.030 0 -0.118
<location> of <PathPoint name="glmin1_l-P2"> changed to 0.005 -0.015 -0.056
<location> of <PathPoint name="glmin2_l-P1"> changed to -0.0616 0.01 -0.101
<location> of <PathPoint name="glmin2_l-P2"> changed to 0.004 -0.009 -0.052
<location> of <PathPoint name="glmin3_l-P2"> changed to -0.004 -0.001 -0.051
<location> of <PathPoint name="semimem_l-P2"> changed to -0.027 -0.041 0.0196
<location> of <PathPoint name="tfl_l-P1"> changed to -0.02 0.011 -0.129