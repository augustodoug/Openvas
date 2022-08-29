![Greenbone Logo](https://www.greenbone.net/wp-content/uploads/gb_logo_resilience_horizontal.png)

## Openvas

Installing Openvas 22.04 using Debian 11.x.

The shell script was created and tested.

##!! IMPORTANT !!
At the end of the script we have the following line

    sudo -u gvm gvmd --create-user admin

At the end, a password hash is generated, which is not a problem, it can be changed using the command below:

    sudo -u gvm gvmd --user=<USERNAME> --new-password=<PASSWORD>
