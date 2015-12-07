#!/bin/bash

USERNAME="ubuntu"
USER_ROOT="/home/$USERNAME/counters_prototype/"
RIAK_ROOT="/home/$USERNAME/riak/"

SCRIPTS_ROOT=$USER_ROOT"scripts/"
OUTPUT_DIR=$USER_ROOT"results-wc/"

REGION_NAME=(
	"US-EAST"
	"US-WEST"
	"EU-WEST"
	)

SERVERS=(
	"ec2-54-172-217-104.compute-1.amazonaws.com"
	"ec2-54-193-55-177.us-west-1.compute.amazonaws.com"
	"ec2-54-171-112-138.eu-west-1.compute.amazonaws.com"
	)

CLIENTS=(
	"ec2-54-165-112-196.compute-1.amazonaws.com:"${SERVERS[0]}
	"ec2-54-193-56-4.us-west-1.compute.amazonaws.com:"${SERVERS[1]}
	"ec2-54-77-149-254.eu-west-1.compute.amazonaws.com:"${SERVERS[2]}
	)

RIAK_PB_PORT=(
	"8087"
	"8087"
	"8087"
	)

	
BUCKET_TYPE="default"
BUCKET="ITEMS"
DEFAULT_KEY="0"
INITIAL_VALUE="30000"
N_KEYS="1"
N_VAL="3"
TIME=180
GENERATOR="uniform_generator"
DEC_PROB="0.8"
HTTP_PORT="8098"



declare -a CLIENTS_REGION=(1)

#<RiakAddress> <RiakPort> <BucketName> 
create_last_write_wins_bucket(){
	curl -X PUT -H 'Content-Type: application/json' -d '{"props":{"allow_mult":true, "n_val":'$N_VAL'}}' "http://"$1":"$2"/buckets/"$3"/props"
}

#<Clients> #<Command>
ssh_command() {
	hosts=($1)
	for h in ${hosts[@]}; do
		OIFS=$IFS
		IFS=':'			
		tokens=($h)
		client=${tokens[0]}
		echo "client  " $client
		ssh -t $USERNAME@$client $2
		IFS=$OIFS
	done
}

#<Clients>
kill_all() {
#	cmd="rm -fr crdtdb/results/*"
	cmd="killall beam.smp"
	ssh_command "$1" "$cmd"
	echo "All clients have stopped"
}

#<Clients>
wait_finish() {
	hosts=($1)
	dontStop=true
	dontStop=true
	while $dontStop; do
		sleep 10
		dontStop=false
		counter=0

		
		for h in ${hosts[@]}; do
			
			OIFS=$IFS
			IFS=':'			
			tokens=($h)
			client=${tokens[0]}
			IFS=$OIFS
			
			echo "Verifying if $client has finished"
			Res="$(ssh $USERNAME@$client pgrep 'beam' | wc -l)"
			#Res="$(ssh $USERNAME@$host ps -C beam --no-headers | wc -l)"
			echo $Res "beam processes are running"
			
			if [ $Res != "0" ]; then
				dontStop=true
			fi
		done



	done
	echo "All clients have stopped"
}

#Process options
while getopts "v:c:kKrdt:" optname
  do
    case "$optname" in
      "v")
		  INITIAL_VALUE=$OPTARG
		  ;;
      "c")
	  	case $OPTARG in
		  'strong')
		  	BUCKET_TYPE="STRONG"
			create_strong_bucket ${SERVERS[0]} $BUCKET
		  ;;
		  'eventual') 
		  	BUCKET_TYPE="default" 
			create_last_write_wins_bucket ${SERVERS[0]} $BUCKET
			;;
	  	esac
        ;;
      "r")
        echo "Get results from clients."
		copy_files "`echo ${CLIENTS[@]}`"
		exit
        ;;
	  "d")
		create_cluster "localhost"
	  	;;
      "t")
  		  THREADS=$OPTARG
  		  ;;
	  "k")
		  kill_all "`echo ${CLIENTS[@]}`"
  		  exit
		  ;;
	  "K")
		  restart_all_servers "`echo ${ALL_SERVERS[@]}`"
		  exit
		  ;; 
      "?")
        echo "Unknown option $OPTARG"
        ;;
      ":")
        echo "No argument value for option $OPTARG"
        ;;
      *)
      # Should not occur
        echo "Unknown error while processing options"
        ;;
    esac
  done
  
echo "Bucket: "$BUCKET_TYPE" "$BUCKET
echo "Initial value: "$INITIAL_VALUE


for j in "${CLIENTS_REGION[@]}"
   do
      :

	  total_clients="3"
  	  filename="experiment_R3_C"$total_clients"_K"$N_KEYS"_V"$INITIAL_VALUE

  	  servers=(${SERVERS[@]})
	  bucket=$(date +%s)
	  
	  for k in $(seq 0 $((${#servers[@]}-1)))
	  	do
			:
			create_last_write_wins_bucket ${SERVERS[k]} $HTTP_PORT $bucket
		done
	  cmd=$SCRIPTS_ROOT"reset-script-counter $INITIAL_VALUE $bucket $BUCKET_TYPE $DEFAULT_KEY ${SERVERS[0]} ${RIAK_PB_PORT[0]} $USER_ROOT"
	  echo $cmd
	  ssh $USERNAME@${SERVERS[0]} $cmd
	  
	  sleep 40
	  
 	  clients=(${CLIENTS[@]})
	  for k in $(seq 0 $((${#clients[@]}-1)))
	  	do
			:
			
			OIFS=$IFS
			IFS=':'			
			tokens=(${clients[$k]})
			client=${tokens[0]}
			server=${tokens[1]}
			
			local_filename=$filename"_"$k
			
			RESULTS_REGION="$OUTPUT_DIR""${REGION_NAME[k]}'_'$total_clients'_'clients'/'3_regions'/'"
			cmd="mkdir -p $RESULTS_REGION && "$SCRIPTS_ROOT"riak-execution-time-script-wc $server ${RIAK_PB_PORT[k]} $bucket $BUCKET_TYPE $j $N_KEYS $TIME $GENERATOR $DEC_PROB $USER_ROOT $RESULTS_REGION ${REGION_NAME[k]} > $RESULTS_REGION""$local_filename"
			echo $cmd
			ssh -f $USERNAME@$client $cmd
			
			IFS=$OIFS
		done
		sleep 5
		wait_finish "`echo ${clients[@]}`"
		sleep 30
	done

#shift $(( ${OPTIND} - 1 )); echo "${*}"
echo "Finish"