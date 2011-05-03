#!/bin/bash

#**************************************************************
# mikutter environment builder for developer (debian & ubuntu)
#**************************************************************

RUBY_SERVER='http://ftp.ruby-lang.org/pub/ruby'
INSTALL_DIR='/opt/miku'
SRC_DIR="${INSTALL_DIR}/src"
DEPENDS='gcc make bzip2 wget pkg-config subversion
         libgtk2.0-dev libyaml-dev libssl-dev zlib1g-dev'

if   [ -e ${INSTALL_DIR} ] && [   -d ${INSTALL_DIR} ]; then
    echo "mikutter setup to ${INSTALL_DIR}"
elif [ -e ${INSTALL_DIR} ] && [ ! -d ${INSTALL_DIR} ]; then
    echo "${INSTALL_DIR} is not directory."
    exit 1
else
    mkdir -p ${INSTALL_DIR}
fi

if [ ! -w ${INSTALL_DIR} ]; then
    echo "${INSTALL_DIR} is not writable."
    exit 1
fi

if [ ! -w ${HOME} ]; then
    echo "${HOME} is not writable."
    exit 1
fi

mkdir -p ${SRC_DIR}
cd       ${INSTALL_DIR}
cat > mikutter-update.sh <<EOF
#!/bin/bash
#- mikutter environment updater -

EOF

#-------------------------------------------------------
# Setup build environment
#-------------------------------------------------------
OLDLANG=${LANG}
LANG=C
LOG=`apt-get -sy install ${DEPENDS}`
LANG=${OLDLANG}

if [ ! `echo ${LOG} | grep "No packages will be" | sed 's/ //g'` ]; then
    echo apt-get install ${DEPENDS}
    if [ $UID = '0' ]; then
        apt-get update
        apt-get -y install ${DEPENDS}
    else
        sudo apt-get update
        sudo apt-get -y install ${DEPENDS}
    fi
fi

#-------------------------------------------------------
# Expand rubygems
#-------------------------------------------------------
echo 'download rubygems.'
GEMS_PATH=`wget -O- 'http://rubyforge.org/frs/?group_id=126&release_id=45671' | \
    egrep -o 'href=".*.tgz"' | head -n 1 | egrep -o '/.*.tgz'`
GEMS_SRC=`echo ${GEMS_PATH} | sed 's/.*\///'`
GEMS_DIR=`echo ${GEMS_SRC}  | sed 's/\.tgz//'`
if [ ! -e ${SRC_DIR}/${GEMS_SRC} ]; then
    wget -P ${SRC_DIR} http://rubyforge.org${GEMS_PATH}
fi
tar xzf ${SRC_DIR}/${GEMS_SRC} -C ${SRC_DIR}


#-------------------------------------------------------
# Setup ruby environment
#-------------------------------------------------------
wget -O- ${RUBY_SERVER} | 
egrep -o '1..?..?-p[0-9]{1,3}' | sort | uniq | 
while read RUBY_VERSION; do
    S_VERSION=`echo ${RUBY_VERSION} | sed 's/-p.*//' | sed 's/\.//g'`
    
    # ruby 1.8.6 is not supported.
    [ ${S_VERSION} = '186' ] && continue
    # [ ${S_VERSION} = '191' ] && continue

    RUBY_SRC=ruby-${RUBY_VERSION}.tar.bz2
    # RUBY_SUFFIX=${S_VERSION}
    RUBY_SUFFIX=""


    # Download ruby source
    if [ ! -e ${SRC_DIR}/${RUBY_SRC} ]; then
    	echo "download ${RUBY_SRC}"
    	wget ${RUBY_SERVER}/${RUBY_SRC} -P ${SRC_DIR}
    else
    	echo "${RUBY_SRC} is already exist."
    fi


    # Build ruby
    echo build ${RUBY_VERSION}
    cd ${SRC_DIR}
    tar xpf ${RUBY_SRC}
    cd ruby-${RUBY_VERSION}
    ./configure --prefix=${INSTALL_DIR}/rb${S_VERSION} \
    	--program-suffix="${RUBY_SUFFIX}" \
    	--enable-shared && \
    	make && make install


    # Install rubygems(for 1.8.x)
    echo "setup gems."
    cd ${INSTALL_DIR}
    if [ `echo ${RUBY_VERSION} | grep '1.8.'` ]; then
    	${INSTALL_DIR}/rb${S_VERSION}/bin/ruby${RUBY_SUFFIX} ${SRC_DIR}/${GEMS_DIR}/setup.rb
    fi


    # Install require libs
    echo 'gem update --system'
    ${INSTALL_DIR}/rb${S_VERSION}/bin/gem${RUBY_SUFFIX} update  --system
    echo 'gem install pkg-config'
    ${INSTALL_DIR}/rb${S_VERSION}/bin/gem${RUBY_SUFFIX} install pkg-config
    echo 'gem install ruby-hmac'
    ${INSTALL_DIR}/rb${S_VERSION}/bin/gem${RUBY_SUFFIX} install ruby-hmac
    echo 'gem install gtk2'
    ${INSTALL_DIR}/rb${S_VERSION}/bin/gem${RUBY_SUFFIX} install gtk2


    # Install scripts
    cd ${INSTALL_DIR}
    echo 'create start, debug, test scripts'
    cat > mikutter-start${S_VERSION}.sh << EOS
#!/bin/bash

cd ${INSTALL_DIR}/mikutter
../rb${S_VERSION}/bin/ruby${RUBY_SUFFIX} \\
  -rubygems mikutter.rb
EOS

    cat > mikutter-debug${S_VERSION}.sh << EOS
#!/bin/bash

cd ${INSTALL_DIR}/mikutter
../rb${S_VERSION}/bin/ruby${RUBY_SUFFIX} -d \\
  -rubygems mikutter.rb --debug
EOS
    
    cat > mikutter-test${S_VERSION}.sh  <<EOF
#!/bin/bash
#- mikutter test script -

cd ${INSTALL_DIR}/mikutter
../rb${S_VERSION}/bin/ruby${RUBY_SUFFIX} -v
../rb${S_VERSION}/bin/gem${RUBY_SUFFIX}  -v
../rb${S_VERSION}/bin/ruby${RUBY_SUFFIX} -rubygems \\
       -e 'require "gtk2"; printf("Gtk2:    %s\n", Gtk::VERSION.join("."))'
../rb${S_VERSION}/bin/ruby${RUBY_SUFFIX} -rubygems \\
       -e 'require "hmac"; printf("HMAC:    %s\n", HMAC::VERSION)'
EOF
    
    echo "${INSTALL_DIR}/rb${S_VERSION}/bin/gem${RUBY_SUFFIX} update --system" >> mikutter-update.sh
    echo "${INSTALL_DIR}/rb${S_VERSION}/bin/gem${RUBY_SUFFIX} update"          >> mikutter-update.sh
done


#-------------------------------------------------------
# Setup mikutter
#-------------------------------------------------------
cd ${INSTALL_DIR}
echo 'checkout mikutter'
svn co svn://mikutter.hachune.net/mikutter/trunk mikutter

cat >> mikutter-update.sh << EOS
cd ${INSTALL_DIR}/mikutter
svn up
EOS

chmod +x mikutter-*.sh

echo 'done.'

