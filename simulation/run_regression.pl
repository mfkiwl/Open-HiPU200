#!/usr/bin/perl -w

#==============================================================================
#                  RUN_REGRESSION.PL        by Xiaoyun Lin @IAIR
#
# Function:	tool for regression control
#
# Inputs:	regression lists
#
# Outputs:	regression results
#
# Command:	perl run_regression.pl <regression list 1> [regression list 2...n]
#
# Limitation:   (V0.5) final loops is not checked.
#               (V0.5) data in memory is not checked.
#               
# History:
#		V0.5	June-18, 2020	Xiaoyun		Initial version
#


use Spreadsheet::ParseExcel;
use Spreadsheet::WriteExcel;

#system("make clean");
#system("make batch_hpu");
system("\\rm -rf log");
system("\\rm -rf log_scalar");
system("\\rm -rf log_step");
system("\\rm -f regression.log");
system("\\rm -f regression.xls");

# sheet colume parameters
my $col_case_num      = 0;
my $col_case_name     = 1;
my $col_case_tb       = 2;
my $col_case_result   = 3;
my $col_case_dueto    = 4;

my $workbook          = Spreadsheet::WriteExcel->new('regression.xls');

# set the format
my $rptheader = $workbook->add_format();
$rptheader->set_bold();
$rptheader->set_size('11');
$rptheader->set_align('center');
$rptheader->set_font('Arial');
$rptheader->set_color('black');

my $passcell = $workbook->add_format();
$passcell->set_size('10');
$passcell->set_align('left');
$passcell->set_font('Arial');
$passcell->set_color('green');

my $failcell = $workbook->add_format();
$failcell->set_size('10');
$failcell->set_align('left');
$failcell->set_font('Arial');
$failcell->set_color('red');



foreach (@ARGV) {
    my $rlist         = $_;
    my $rlist_name    = "";
    my $rlist_mode    = "";
    my $log_path      = "";
    my $tc_mode       = "";
    print "rlist = $rlist\n";
    
    if ($rlist =~ /(\w+.\w+)@(\w+)/) {
        $rlist_name    = $1;
        $rlist_mode    = $2;
    } else {
        next;
    }
    print "rlist_name = $rlist_name;\t rlist_mode = $rlist_mode\n";
    open (I_RLIST, "../tests/$rlist_name") || die "ERROR: ../tests/$rlist_name could not be opened!";

    if ($rlist_mode =~ /scalar/) {     		# scalar mode
        $log_path  = "log_scalar";
        $tc_mode   = "scalar"
    } elsif ($rlist_mode =~ /step/) {		# single step mode
        $log_path  = "log_step";
        $tc_mode   = "step"
    } else {								# super scalar mode
        $log_path  = "log";
        $tc_mode   = "super"
    }

    # create a new sheet and fill in the header line
    my $sheet         = $workbook->add_worksheet($rlist);
    my $sheet_row     = 0;
    $sheet->write(0, $col_case_num,    "No."       , $rptheader);
    $sheet->write(0, $col_case_name,   "Name"      , $rptheader);
    $sheet->write(0, $col_case_tb,     "TB"        , $rptheader);
    $sheet->write(0, $col_case_result, "Result"    , $rptheader);
    $sheet->write(0, $col_case_dueto,  "Due to"    , $rptheader);
    $sheet->freeze_panes(1,0);
    $sheet->set_column('A:D', 15);
    $sheet->set_column('E:E', 30);

   

    while (<I_RLIST>) {
        chomp;
        if ($_ =~ /^\#/) {     		# comments
            #print "comments: $_\n";
            next;
        } elsif ($_ =~ /^\s*$/) {	# space
            #print "space: $_\n";
            next;
        } elsif ($_ =~ /(\w+)\s+(\w+)/) {
            my $case_name = $1;
            my $tb_type   = $2;
            $sheet_row = $sheet_row + 1;
            print "case: $case_name; tb: $tb_type\n";
            print "$sheet_row - $case_name is running\n";

            # step 1: run_tc
            if ($tb_type eq "hpu") {
                system ("bash run_tc $case_name -batch -$rlist_mode >> regression.log");
            } elsif ($tb_type eq "hpu_v") {
                system ("bash run_v_tc $case_name -batch -$rlist_mode >> regression.log");
            } elsif ($tb_type eq "hpu_d") {
                system ("bash run_debug_tc $case_name -batch >> regression.log");
            } else {
                #print "Error: TB is not found\n";
                $sheet->write($sheet_row, $col_case_num,    $sheet_row,                          $failcell);
                $sheet->write($sheet_row, $col_case_name,   $case_name,                          $failcell);
                $sheet->write($sheet_row, $col_case_tb,     $tb_type,                            $failcell);
                $sheet->write($sheet_row, $col_case_result, "Failed",                            $failcell);
                $sheet->write($sheet_row, $col_case_dueto,  "TB is missing",                     $failcell);
                next;
            }
                

            # step 2: grep timeout in run.log 
            system ("grep -i timeout $log_path/$case_name/run.log > $log_path/$case_name/temp.log");
            if (-z "$log_path/$case_name/temp.log") {
                #print "  - no timeout\n";
            } else {
                #print "  * timeout occured during simulation\n";
                $sheet->write($sheet_row, $col_case_num,    $sheet_row,                          $failcell);
                $sheet->write($sheet_row, $col_case_name,   $case_name,                          $failcell);
                $sheet->write($sheet_row, $col_case_tb,     $tb_type,                            $failcell);
                $sheet->write($sheet_row, $col_case_result, "Failed",                            $failcell);
                $sheet->write($sheet_row, $col_case_dueto,  "Timeout occured during simulation", $failcell);
                next;
            }
            system ("\\rm $log_path/$case_name/temp.log");
 
            # step 3: grep errors in run.log 
            #system ("grep -i force $log_path/$case_name/run.log > $log_path/$case_name/temp.log");		# error -> force, for testing
            system ("grep -i error $log_path/$case_name/run.log > $log_path/$case_name/temp.log");
            if (-z "$log_path/$case_name/temp.log") {
                #print "  - no errors\n";
            } else {
                #print "  * error occured during simulation\n";
                $sheet->write($sheet_row, $col_case_num,    $sheet_row,                          $failcell);
                $sheet->write($sheet_row, $col_case_name,   $case_name,                          $failcell);
                $sheet->write($sheet_row, $col_case_tb,     $tb_type,                            $failcell);
                $sheet->write($sheet_row, $col_case_result, "Failed",                            $failcell);
                $sheet->write($sheet_row, $col_case_dueto,  "Error occured during simulation",   $failcell);
                next;
            }
            system ("\\rm $log_path/$case_name/temp.log");

            # step 4: check the loops

            # step 5: compare the results with the reference files
            # (1) rat
            if (-e "../tests/$case_name/ref/rat.info") {
                system ("cd $log_path/$case_name; perl ../../rat_prf.pl");
                if (-e "$log_path/$case_name/rat.info") {
                } else {
                    $sheet->write($sheet_row, $col_case_num,    $sheet_row,                          $failcell);
                    $sheet->write($sheet_row, $col_case_name,   $case_name,                          $failcell);
                    $sheet->write($sheet_row, $col_case_tb,     $tb_type,                            $failcell);
                    $sheet->write($sheet_row, $col_case_result, "Failed",                            $failcell);
                    $sheet->write($sheet_row, $col_case_dueto,  "Error in rat.info generation",      $failcell);
                    next;
                }    

                my $rat_mismatch_flag = rat_compare("../tests/$case_name/ref/rat.info", "$log_path/$case_name/rat.info", $tc_mode);
#                system ("diff $log_path/$case_name/rat.info ../tests/$case_name/ref/rat.info > $log_path/$case_name/temp.log");
#                if (-z "$log_path/$case_name/temp.log") {
                if ($rat_mismatch_flag eq 0) {
                    #print "  - no mismatch in rat\n";
                } else {
                    #print "  * mismatch in rat\n";
                    $sheet->write($sheet_row, $col_case_num,    $sheet_row,                          $failcell);
                    $sheet->write($sheet_row, $col_case_name,   $case_name,                          $failcell);
                    $sheet->write($sheet_row, $col_case_tb,     $tb_type,                            $failcell);
                    $sheet->write($sheet_row, $col_case_result, "Failed",                            $failcell);
                    $sheet->write($sheet_row, $col_case_dueto,  "Mismatch in rat",                   $failcell);
                    next;
                }
            }
            
            # (2) prf
            if (-e "../tests/$case_name/ref/prf.info") {
                system ("cd $log_path/$case_name; perl ../../rat_prf.pl");
                if (-e "$log_path/$case_name/prf.info") {
                } else {
                    $sheet->write($sheet_row, $col_case_num,    $sheet_row,                          $failcell);
                    $sheet->write($sheet_row, $col_case_name,   $case_name,                          $failcell);
                    $sheet->write($sheet_row, $col_case_tb,     $tb_type,                            $failcell);
                    $sheet->write($sheet_row, $col_case_result, "Failed",                            $failcell);
                    $sheet->write($sheet_row, $col_case_dueto,  "Error in prf.info generation",      $failcell);
                    next;
                }    

                system ("diff $log_path/$case_name/prf.info ../tests/$case_name/ref/prf.info > $log_path/$case_name/temp.log");
                if (-z "$log_path/$case_name/temp.log") {
                    #print "  - no mismatch in prf\n";
                } else {
                    #print "  * mismatch in prf\n";
                    $sheet->write($sheet_row, $col_case_num,    $sheet_row,                          $failcell);
                    $sheet->write($sheet_row, $col_case_name,   $case_name,                          $failcell);
                    $sheet->write($sheet_row, $col_case_tb,     $tb_type,                            $failcell);
                    $sheet->write($sheet_row, $col_case_result, "Failed",                            $failcell);
                    $sheet->write($sheet_row, $col_case_dueto,  "Mismatch in prf",                   $failcell);
                    next;
                }
            }
            
            # (3) csr
            if (-e "../tests/$case_name/ref/csr.info") {
                if (-e "$log_path/$case_name/csr.info") {
                } else {
                    $sheet->write($sheet_row, $col_case_num,    $sheet_row,                          $failcell);
                    $sheet->write($sheet_row, $col_case_name,   $case_name,                          $failcell);
                    $sheet->write($sheet_row, $col_case_tb,     $tb_type,                            $failcell);
                    $sheet->write($sheet_row, $col_case_result, "Failed",                            $failcell);
                    $sheet->write($sheet_row, $col_case_dueto,  "Error in csr.info generation",      $failcell);
                    next;
                }    

                my $csr_mismatch_flag = csr_compare("../tests/$case_name/ref/csr.info", "./$log_path/$case_name/csr.info"); 
                if ($csr_mismatch_flag eq 0) {
                    #print "  - no mismatch in csr\n";
                } else {
                    #print "  * mismatch in csr\n";
                    $sheet->write($sheet_row, $col_case_num,    $sheet_row,                          $failcell);
                    $sheet->write($sheet_row, $col_case_name,   $case_name,                          $failcell);
                    $sheet->write($sheet_row, $col_case_tb,     $tb_type,                            $failcell);
                    $sheet->write($sheet_row, $col_case_result, "Failed",                            $failcell);
                    $sheet->write($sheet_row, $col_case_dueto,  "Mismatch in csr",                   $failcell);
                    next;
                }
            }


            # (4) mem
            #if (-e "") {

            #}

            $sheet->write($sheet_row, $col_case_num,    $sheet_row,                          $passcell);
            $sheet->write($sheet_row, $col_case_name,   $case_name,                          $passcell);
            $sheet->write($sheet_row, $col_case_tb,     $tb_type,                            $passcell);
            $sheet->write($sheet_row, $col_case_result, "Passed",                            $passcell);

        }

    }

} 


sub csr_compare {
    my $input_ref = $_[0];
    my $input_act = $_[1];
    my $mismatch_flag = 0;

    open (I_REF, $input_ref) || die "ERROR: $input_ref could not be opened!";
    
    while (<I_REF>) {
        chomp;
        my $ref_line = $_;
        #print "$ref_line\n";
        if ($ref_line =~ /^\#/) {
            next;
        } elsif ($ref_line =~ /(\w+)\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)/) {
            my $ref_csr_name  = $1;
            my $ref_csr_value = $2;
            my $ref_csr_mask  = $3;
            #print "ref_line: $ref_line => ref_csr_name: $ref_csr_name; ref_csr_value: $ref_csr_value; ref_csr_mask: $ref_csr_mask.\n";
            open (I_ACT, $input_act) || die "ERROR: $input_act could not be opened!";
            while (<I_ACT>) {
                my $act_line = $_;
                my $act_csr_name  = "";
                my $act_csr_value = "";
                if ($act_line =~ /(\w+)\s+([0-9a-fA-F]+)/) {
                     $act_csr_name  = $1;
                     $act_csr_value = $2;
                     #print "act_line: $ref_line => act_csr_name: $act_csr_name; act_csr_value: $act_csr_value.\n";
                } 
                if ($ref_csr_name eq $act_csr_name) {
                     if (((hex("0x".$ref_csr_value)) & (hex("0x".$ref_csr_mask))) != ((hex("0x".$act_csr_value)) & (hex("0x".$ref_csr_mask)))) {
                         $mismatch_flag = 1;
                     } else {
                         next;
                     }
                }
            }
            close I_ACT;
        }
    }

    close I_REF;
    return $mismatch_flag;

}


sub rat_compare {
    my $input_ref         = $_[0];
    my $input_act         = $_[1];
    my $tc_mode           = $_[2];
    my $mismatch_flag     = 0;

    my @ref_rat_logic     = ();
    my @ref_rat_physical  = ();
    my @ref_rat_value     = ();
    my @act_rat_logic     = ();
    my @act_rat_physical  = ();
    my @act_rat_value     = ();
    my $ref_num           = 0;
    my $act_num           = 0;

    open (I_REF, $input_ref) || die "ERROR: $input_ref could not be opened!";
    open (I_ACT, $input_act) || die "ERROR: $input_act could not be opened!";
    
    while (<I_REF>) {
        chomp;
        my $ref_line = $_;
        #print "$ref_line\n";
        if ($ref_line =~ /logic\s+physical\s+value/) {		# header line
            next;
        } elsif ($ref_line =~ /(\w+)\s+(\d+)\s+(0x.[0-9a-fA-F]+)/) {
            $ref_rat_logic[$ref_num]    = $1;
            $ref_rat_physical[$ref_num] = $2;
            $ref_rat_value[$ref_num]    = $3;
            $ref_num                    = $ref_num + 1;
        }
    }

    while (<I_ACT>) {
        chomp;
        my $act_line = $_;
        #print "$act_line\n";
        if ($act_line =~ /logic\s+physical\s+value/) {		# header line
            next;
        } elsif ($act_line =~ /(\w+)\s+(\d+)\s+(0x.[0-9a-fA-F]+)/) {
            $act_rat_logic[$act_num]    = $1;
            $act_rat_physical[$act_num] = $2;
            $act_rat_value[$act_num]    = $3;
            $act_num                    = $act_num + 1;
        }
    }
    
    my $ref_size   = @ref_rat_logic;
    my $comp_index = 0;


    for ($comp_index = 0; $comp_index < $ref_size; $comp_index ++) {

        if ($tc_mode eq "super") {
            if ($act_rat_physical[$comp_index] ne $ref_rat_physical[$comp_index]) {
                $mismatch_flag = 1;
            } 
            if ($act_rat_value[$comp_index] ne $ref_rat_value[$comp_index]) {
                $mismatch_flag = 1;
            } 
        } else {
            if ($act_rat_value[$comp_index] ne $ref_rat_value[$comp_index]) {
                $mismatch_flag = 1;
            } 

        }

    }

    close I_REF;
    close I_ACT;
    return $mismatch_flag;

}
