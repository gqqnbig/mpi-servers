#!/usr/bin/zsh -e

while true; do
	case $1 in
		--email)
			email=$2; shift 2;;
		--public-key)
			publicKey=$2; shift 2;;
		--test)
			isTest=true; shift;;
		*)
			break;;
	esac
done

username=$1

if [[ $isTest == true ]]; then
	localAptUserId=$(getent group aptuser | cut -d: -f3)
	remoteAptUserId=$(sudo -u $SUDO_USER ssh eureka 'getent group aptuser' | cut -d: -f3)

	if [[ "$localAptUserId" != "$remoteAptUserId" ]]; then
		echo "Error: The id of group aptuser is $localAptUserId on local while $remoteAptUserId on remote."
		exit 1
	fi
	exit
fi


sudo adduser --conf adduser.conf --gecos ",,,,$email" --disabled-password $username

uid=$(id -u $username)
gid=$(id -g $username)

btrfs qgroup create 1/$uid /home

mv /home/$username /home/$username-tmp

btrfs subvolume create -i 1/$uid /home/$username
btrfs subvolume create -i 1/$uid /home/shared/$username
chown $username: /home/$username
chown $username: /home/shared/$username

# (D) sets the GLOB_DOTS option for the current pattern
mv /home/$username-tmp/*(D) /home/$username
rm -rf /home/$username-tmp

ln -s /home/shared/$username /home/$username/shared

# When user runs `srun` on aha, the user's groups are captured
# on aha, then transfered to eureka. 
# Although we put the user to group aptuser, the sudoers file doesn't
# have corresponding rules so the user cannot run `sudo apt` on aha.
# Eureka has the corresponding sudoers rule.
usermod -aG aptuser,conda-cache $username

sudo -u $username cp -r ../slurm-examples /home/$username/shared/



gecos=$(getent passwd $username | cut -d ':' -f 5)

remoteFile=/home/$SUDO_USER/shared/remote-add-user
cat <<HERE > $remoteFile
#!/bin/bash -e
sudo addgroup --gid $gid $username
# It's not documented clearly, but --gid requires the existence of GID.
sudo adduser --gecos ",,,,$email" --disabled-login --uid $uid --gid $gid $username
sudo usermod -aG conda-cache $username

sudo ln -s /home/shared/$username /home/$username/shared
HERE

chmod +x $remoteFile

if ! sudo -u $SUDO_USER ssh eureka $remoteFile; then
	echo "Failed to execute remote command,"
	echo "Please run ~/shared/remote-add-user on eureka."
fi
if ! sudo -u $SUDO_USER ssh tatooine $remoteFile; then
	echo "Failed to execute remote command,"
	echo "Please run ~/shared/remote-add-user on tatooine."
fi

mkdir -p /home/$username/.ssh
echo $publicKey > /home/$username/.ssh/authorized_keys
chmod 700 /home/$username/.ssh
chmod 600 /home/$username/.ssh/authorized_keys
chown -R $username:$username /home/$username/.ssh

emailBody="Account: $username
Public Key: $publicKey"
sendemail -f aha@ipm.edu.mo -t $email -s mail.ipm.edu.mo -u 'Shine Cluster Account Created' -m "$emailBody"
