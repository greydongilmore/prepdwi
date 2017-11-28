#!/bin/bash



if [ "$#" -lt 3 ]
then
 echo "Usage: $0 bids_dir output_dir {participant,group} "
 echo "          [--participant_label=PARTICIPANT_LABEL[,PARTICIPANT_LABEL,...]]"
 echo "          [--acq_label=ACQ_LABEL[,ACQ_LABEL,...]]"
 echo ""
 exit 1
fi
in_bids=$1 
out_folder=$2 
analysis_level=$3


shift 3

while :; do
      case $1 in
     -h|-\?|--help)
	     usage
            exit
              ;;
     --participant_label )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                participant_label=$2
                  shift
	      else
              die 'error: "--participant" requires a non-empty option argument.'
            fi
              ;;
     --participant_label=?*)
          participant_label=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --participant_label=)         # handle the case of an empty --participant=
         die 'error: "--participant_label" requires a non-empty option argument.'
          ;;
     --acq_label )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                acq_label=$2
                  shift
	      else
              die 'error: "--acq_label" requires a non-empty option argument.'
            fi
              ;;
     --acq_label=?*)
          acq_label=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --acq_label=)         # handle the case of an empty --acq=
         die 'error: "--acq_label" requires a non-empty option argument.'
          ;;
      -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
              ;;
     *)               # Default case: No more options, so break out of the loop.
          break
    esac
  
 shift
  done


echo acq_label=$acq_label
echo participant_label=$participant_label

if [ -e $in_bids ]
then
	in_bids=`realpath $in_bids`
else
	echo "ERROR: bids_dir does not exist!"
	exit 1
fi


if [ "$analysis_level" = "participant" ]
then
 echo " running participant level analysis"
 else
  echo "only participant level analysis is enabled"
  exit 0
fi

dwi_prefix=uncorrected

participants=$in_bids/participants.tsv

mkdir -p $out_folder

pushd $out_folder
echo $participants

if [ -n "$acq_label" ]
then
  searchstring=_acq-\{${acq_label}\}\*dwi.nii.gz
else
  searchstring=*dwi.nii.gz
fi

if [ -n "$participant_label" ]
then
subjlist=`echo $participant_label | sed  's/,/\ /g'` 
else
subjlist=`tail -n +2 $participants | awk '{print $1}'`
fi

for subj in $subjlist 
do
 
Ndwi=`eval ls $in_bids/$subj/dwi/${subj}${searchstring} | wc -l`
 echo Ndwi=$Ndwi
 importDWI ${dwi_prefix} $Ndwi `eval ls $in_bids/$subj/dwi/${subj}${searchstring}` $subj
 processDwiDenoise uncorrected $subj
 processUnring uncorrected_denoise $subj

 if [ "$Ndwi" = "1" ] #simple but possibly naive way of determining when to use topup
 then
 processEddyNoTopUp uncorrected_denoise_unring $subj
  eddy=eddy
 else
  processTopUp uncorrected_denoise_unring $subj
  processEddy uncorrected_denoise_unring $subj
  eddy=topup_eddy
 fi

#  processBedpost uncorrected_denoise_unring_$eddy $subj
done


popd
