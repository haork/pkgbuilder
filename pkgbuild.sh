#!/bin/sh
# ----------------------------------------------------------------------
# name:         pkgbuild.sh
# version:      1.0
# createTime:   2018-05-15
# description:  Mac应用打包签名脚本
# author:       haork
# email:        haork0731@thundersoft.com
# parameters:   1.待处理文件名(zip)
#               2.生成的pkg文件路径
#               3.应用包名(packageName)
#               4.应用版本号(versionName)
#               5.应用名(buildName)
# return:       packageName.pkg
# ----------------------------------------------------------------------

rootPath="root"
flatPath="flat";

tempPath="temp";
#certPath="/home/user/Desktop/EMM-SERVER/thunderemm-server-web/src/main/webapp/resources/PkgInfolib/cert";
certPath="cert";

createDirs() {
    echo "create dirs"
    #清空目录结构
    echo "rm -rf $*"
    rm -rf $*

    #创建目录结构
    echo "mkdir -p $*"
    mkdir -p $*
}

extractZip() {
    echo "extract file:$1"
    unzip $1 -d root/ > /dev/null
    echo "extract complete"
}

compressPayload() {
    echo "compress payload from $1 to $2"
    (cd $1 && find . | bsdcpio -o --format odc --owner 0:80 | gzip -c) > $2
}

compressBom() {
    echo "compress bom from $1 to $2"
    mkbom -u 0 -g 80 $1 $2
}


# targetFile packageName versionName bundleName numberOfFiles installKBytes
writePackageInfo() {
    if [ $# -ge 6 ]
    then
    echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>
      <pkg-info overwrite-permissions=\"true\" relocatable=\"false\" identifier=\"$2\" postinstall-action=\"none\" version=\"$3\"
        format-version=\"2\" generator-version=\"InstallCmds-611 (16G1314)\" install-location=\"/Applications/\" auth=\"root\" preserve-xattr=\"true\">
          <payload numberOfFiles=\"$5\" installKBytes=\"$6\"/>
          <bundle path=\"./$4\" id=\"$2\" CFBundleVersion=\"$3\"/>
          <bundle-version>
              <bundle id=\"$2\"/>
          </bundle-version>
      </pkg-info>">>$1
    else
        echo "lack of parameters to writePackageInfo";
    fi
}

# targetFile packageName versionName bundleName installKBytes
writeDistribution() {
    if [ $# -ge 5 ]
    then
    echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>
    <installer-gui-script minSpecVersion=\"2\">
        <pkg-ref id=\"$2\">
            <bundle-version>
                <bundle CFBundleShortVersionString=\"$3\" CFBundleVersion=\"10370\" id=\"$2\" path=\"$4\"/>
            </bundle-version>
        </pkg-ref>
        <product id=\"$2\" version=\"$3\"/>
        <title>$4</title>
        <options customize=\"never\" require-scripts=\"false\"/>
        <volume-check>
            <allowed-os-versions>
                <os-version min=\"10.10\"/>
            </allowed-os-versions>
        </volume-check>
        <choices-outline>
            <line choice=\"default\">
                <line choice=\"$2\"/>
            </line>
        </choices-outline>
        <choice id=\"default\" title=\"$4\" versStr=\"$3\"/>
        <choice id=\"$2\" title=\"$4\" visible=\"false\" customLocation=\"/Applications/\">
            <pkg-ref id=\"$2\"/>
        </choice>
        <pkg-ref id=\"$2\" version=\"$3\" onConclusion=\"none\" installKBytes=\"$5\">#$2.pkg</pkg-ref>
    </installer-gui-script>">>$1
    else
        echo "lack of parameters to writePackageInfo";
    fi
}

packagePkg() {
    echo "compress and package pkg from $1 to $2"
    (cd $1 && xar --compression none -cf $2 *)
}

signPkg() {
    xar --sign -f $1 --digestinfo-to-sign "$tempPath/digestinfo.dat" --sig-size 256 --cert-loc "$certPath/cert00" --cert-loc "$certPath/cert01"

    openssl rsautl -sign -inkey "$certPath/key.pem" -in "$tempPath/digestinfo.dat" -out "$tempPath/signature.dat"

    xar --inject-sig "$tempPath/signature.dat" -f $1
    echo "sign package $1 success!"
}

cleanUp() {
    echo "cleaning..."
    rm -rf $*
}

if [ $# -ge 4 ]
then
    srcFile=$1
    dstFile=$2
    packageName=$3
    versionName=$4
    bundleName=$5

    packagePath="$flatPath/$packageName.pkg"
    resourcesPath="$flatPath/Resources"

    payloadFile="$packagePath/Payload"
    bomFile="$packagePath/Bom"

    packageInfoFile="$packagePath/PackageInfo"
    distributionFile="$flatPath/Distribution"

    createDirs $rootPath $flatPath $tempPath $packagePath $resourcesPath

    extractZip $srcFile

    compressPayload $rootPath $payloadFile

    compressBom $rootPath $bomFile

    numberOfFiles=`ls -lR $rootPath | grep "^-"|wc -l`
    echo "numberOfFiles is $numberOfFiles"

    installKBytes=`du -sb $rootPath | awk '{print int($1/1024)}'`
    echo "installKBytes is $installKBytes"

    #创建packageInfoFile
    writePackageInfo $packageInfoFile $packageName $versionName $bundleName $numberOfFiles $installKBytes

    #创建distributionFile
    writeDistribution $distributionFile $packageName $versionName $bundleName $installKBytes

    packagePkg $flatPath $dstFile
    signPkg $dstFile

    cleanUp $rootPath $flatPath $tempPath
else
    echo "usage: pkgbuild.sh srcFile dstFile packageName versionName bundleName"
fi