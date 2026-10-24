#!/usr/bin/env python3
"""Reproducible Xcode project + first-party geometric app icon; no dependencies at build time."""
import hashlib, json, plistlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
objects = {}
def uid(value): return hashlib.sha1(value.encode()).hexdigest()[:24].upper()
def add(object_key, isa, **values):
    key = uid(object_key); objects[key] = {'isa': isa, **values}; return key

def config_list(name, base):
    configs = []
    for build in ['Debug', 'Release']:
        settings = dict(base)
        if build == 'Debug': settings.update(SWIFT_OPTIMIZATION_LEVEL='-Onone', DEBUG_INFORMATION_FORMAT='dwarf', ENABLE_TESTABILITY='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG')
        else: settings.update(SWIFT_OPTIMIZATION_LEVEL='-O', DEBUG_INFORMATION_FORMAT='dwarf-with-dsym', SWIFT_COMPILATION_MODE='wholemodule')
        configs.append(add(name+build,'XCBuildConfiguration',buildSettings=settings,name=build))
    return add(name+'configlist','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')

app_files=[]; app_build=[]
for p in sorted((ROOT/'TicketLibre').rglob('*.swift')):
    rel=p.relative_to(ROOT/'TicketLibre').as_posix()
    f=add('file:'+rel,'PBXFileReference',lastKnownFileType='sourcecode.swift',path=rel,sourceTree='<group>')
    app_files.append(f); app_build.append(add('build:'+rel,'PBXBuildFile',fileRef=f))
resources=[]
for name,typ in [('Assets.xcassets','folder.assetcatalog'),('PrivacyInfo.xcprivacy','text.xml')]:
    f=add(name,'PBXFileReference',lastKnownFileType=typ,path=name,sourceTree='<group>'); app_files.append(f); resources.append(add('res:'+name,'PBXBuildFile',fileRef=f))
info=add('Info.plist','PBXFileReference',lastKnownFileType='text.plist.xml',path='Info.plist',sourceTree='<group>'); app_files.append(info)
app_group=add('appgroup','PBXGroup',children=app_files,path='TicketLibre',sourceTree='<group>')
testfile=add('testfile','PBXFileReference',lastKnownFileType='sourcecode.swift',path='TicketLibreTests.swift',sourceTree='<group>')
testbuild=add('testbuild','PBXBuildFile',fileRef=testfile)
testgroup=add('testgroup','PBXGroup',children=[testfile],path='TicketLibreTests',sourceTree='<group>')
app_product=add('appproduct','PBXFileReference',explicitFileType='wrapper.application',includeInIndex=0,path='TicketLibre.app',sourceTree='BUILT_PRODUCTS_DIR')
test_product=add('testproduct','PBXFileReference',explicitFileType='wrapper.cfbundle',includeInIndex=0,path='TicketLibreTests.xctest',sourceTree='BUILT_PRODUCTS_DIR')
products=add('products','PBXGroup',children=[app_product,test_product],name='Products',sourceTree='<group>')
main=add('main','PBXGroup',children=[app_group,testgroup,products],sourceTree='<group>')
def phase(name,isa,files): return add(name,isa,buildActionMask=2147483647,files=files,runOnlyForDeploymentPostprocessing=0)
app_sources=phase('appsources','PBXSourcesBuildPhase',app_build)
app_resources=phase('appresources','PBXResourcesBuildPhase',resources)
app_frameworks=phase('appframeworks','PBXFrameworksBuildPhase',[])
test_sources=phase('testsources','PBXSourcesBuildPhase',[testbuild])
test_frameworks=phase('testframeworks','PBXFrameworksBuildPhase',[])
project_id=uid('project'); app_id=uid('app'); test_id=uid('test')
project_config=config_list('project',dict(CLANG_ENABLE_MODULES='YES',CLANG_ENABLE_OBJC_ARC='YES',CLANG_WARN_DOCUMENTATION_COMMENTS='YES',GCC_C_LANGUAGE_STANDARD='gnu17',IPHONEOS_DEPLOYMENT_TARGET='18.0',SDKROOT='iphoneos',SWIFT_VERSION='5.0',SWIFT_STRICT_CONCURRENCY='minimal',ENABLE_USER_SCRIPT_SANDBOXING='YES',GCC_NO_COMMON_BLOCKS='YES'))
app_config=config_list('app',dict(PRODUCT_NAME='$(TARGET_NAME)',PRODUCT_BUNDLE_IDENTIFIER='org.ticketlibre.ios',MARKETING_VERSION='1.0.1',CURRENT_PROJECT_VERSION='2',INFOPLIST_FILE='TicketLibre/Info.plist',GENERATE_INFOPLIST_FILE='NO',ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME='AccentColor',CODE_SIGN_STYLE='Automatic',DEVELOPMENT_TEAM='',TARGETED_DEVICE_FAMILY='1',SUPPORTED_PLATFORMS='iphoneos iphonesimulator',SUPPORTS_MACCATALYST='NO',LD_RUNPATH_SEARCH_PATHS=['$(inherited)','@executable_path/Frameworks'],SWIFT_EMIT_LOC_STRINGS='YES'))
test_config=config_list('test',dict(PRODUCT_NAME='$(TARGET_NAME)',PRODUCT_BUNDLE_IDENTIFIER='org.ticketlibre.ios.tests',GENERATE_INFOPLIST_FILE='YES',TARGETED_DEVICE_FAMILY='1',CODE_SIGN_STYLE='Automatic',TEST_HOST='$(BUILT_PRODUCTS_DIR)/TicketLibre.app/TicketLibre',BUNDLE_LOADER='$(TEST_HOST)',SUPPORTED_PLATFORMS='iphoneos iphonesimulator',LD_RUNPATH_SEARCH_PATHS=['$(inherited)','@executable_path/Frameworks','@loader_path/Frameworks']))
proxy=add('proxy','PBXContainerItemProxy',containerPortal=project_id,proxyType=1,remoteGlobalIDString=app_id,remoteInfo='TicketLibre')
dep=add('dep','PBXTargetDependency',target=app_id,targetProxy=proxy)
add('app','PBXNativeTarget',buildConfigurationList=app_config,buildPhases=[app_sources,app_frameworks,app_resources],buildRules=[],dependencies=[],name='TicketLibre',productName='TicketLibre',productReference=app_product,productType='com.apple.product-type.application')
add('test','PBXNativeTarget',buildConfigurationList=test_config,buildPhases=[test_sources,test_frameworks],buildRules=[],dependencies=[dep],name='TicketLibreTests',productName='TicketLibreTests',productReference=test_product,productType='com.apple.product-type.bundle.unit-test')
add('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2600','TargetAttributes':{app_id:{'CreatedOnToolsVersion':'26.0'},test_id:{'CreatedOnToolsVersion':'26.0','TestTargetID':app_id}}},buildConfigurationList=project_config,compatibilityVersion='Xcode 14.0',developmentRegion='es',hasScannedForEncodings=0,knownRegions=['es','en','Base'],mainGroup=main,productRefGroup=products,projectDirPath='',projectRoot='',targets=[app_id,test_id])
def emit(v,level=0):
    if isinstance(v,dict): return '{\n' + '\n'.join('\t'*(level+1)+json.dumps(str(k),ensure_ascii=False)+' = '+emit(val,level+1)+';' for k,val in v.items())+'\n'+'\t'*level+'}'
    if isinstance(v,list): return '(\n'+''.join('\t'*(level+1)+emit(x,level+1)+',\n' for x in v)+'\t'*level+')'
    if isinstance(v,int): return str(v)
    return json.dumps(v,ensure_ascii=False)
(ROOT/'TicketLibre.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n'+emit(dict(archiveVersion=1,classes={},objectVersion=56,objects=objects,rootObject=project_id))+'\n')

def ref(t,name,product): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{t}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:TicketLibre.xcodeproj"/>'
appref=ref(app_id,'TicketLibre','TicketLibre.app'); testref=ref(test_id,'TicketLibreTests','TicketLibreTests.xctest')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{appref}</BuildActionEntry>
  <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{testref}</BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{testref}</TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(ROOT/'TicketLibre.xcodeproj/xcshareddata/xcschemes/TicketLibre.xcscheme').write_text(scheme)
plist={
 'CFBundleDevelopmentRegion':'es','CFBundleDisplayName':'TicketLibre','CFBundleExecutable':'$(EXECUTABLE_NAME)',
 'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)',
 'CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0.1','CFBundleVersion':'2',
 'LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UIApplicationSupportsIndirectInputEvents':True,
 'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
 'NSCameraUsageDescription':'Escanear los tickets que decidas guardar. El reconocimiento se realiza en el dispositivo.',
 'NSFaceIDUsageDescription':'Proteger el acceso a tus tickets si activas el bloqueo de la aplicación.',
 'CFBundleURLTypes':[{'CFBundleURLName':'org.ticketlibre.ios','CFBundleURLSchemes':['ticketlibre']}],
 'ITSAppUsesNonExemptEncryption':False,
}
(ROOT/'TicketLibre/Info.plist').write_bytes(plistlib.dumps(plist))
privacy={'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[],'NSPrivacyCollectedDataTypes':[], 'NSPrivacyAccessedAPITypes':[{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryUserDefaults','NSPrivacyAccessedAPITypeReasons':['CA92.1']},{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryFileTimestamp','NSPrivacyAccessedAPITypeReasons':['C617.1']} ]}
(ROOT/'TicketLibre/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps(privacy))
print('Generated Xcode project, scheme, Info.plist and Privacy manifest')
