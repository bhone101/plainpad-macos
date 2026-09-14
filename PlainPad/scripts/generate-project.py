#!/usr/bin/env python3
"""Generate the dependency-free Xcode project; no xcodegen installation needed."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent
objects = {}
def ident(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def add(key, value): objects[ident(key)] = value; return ident(key)
def arr(values): return '(' + ', '.join(values) + (',)' if values else ')')
def ref(path, kind):
    return add(path, '{isa = PBXFileReference; lastKnownFileType = '+kind+'; path = "'+path+'"; sourceTree = "<group>";}')
sources = ['Sources/'+p.name for p in sorted((root/'Sources').glob('*.swift'))]
tests = ['Tests/TestCases.swift','Tests/PlainPadTests.swift']
refs = {p:ref(p,'sourcecode.swift') for p in sources+tests}
icon = ref('Resources/AppIcon.icns','image.icns'); plist = ref('Resources/Info.plist','text.plist.xml'); readme = ref('README.md','net.daringfireball.markdown')
appProduct = add('appProduct','{isa = PBXFileReference; explicitFileType = wrapper.application; path = PlainPad.app; sourceTree = BUILT_PRODUCTS_DIR;}')
testProduct = add('testProduct','{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = PlainPadTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;}')
def phase(key,isa, files):
    builds = [add(key+p,'{isa = PBXBuildFile; fileRef = '+r+';}') for p,r in files]
    return add(key,'{isa = '+isa+'; buildActionMask = 2147483647; files = '+arr(builds)+'; runOnlyForDeploymentPostprocessing = 0;}')
appSources = phase('appSources','PBXSourcesBuildPhase',[(p,refs[p]) for p in sources])
testSources = phase('testSources','PBXSourcesBuildPhase',[(p,refs[p]) for p in tests])
resources = phase('resources','PBXResourcesBuildPhase',[('icon',icon)])
frameworks = phase('frameworks','PBXFrameworksBuildPhase',[])
products = add('products','{isa = PBXGroup; children = '+arr([appProduct,testProduct])+'; name = Products; sourceTree = "<group>";}')
mainGroup = add('mainGroup','{isa = PBXGroup; children = '+arr(list(refs.values())+[icon,plist,readme,products])+'; sourceTree = "<group>";}')
def configs(key, settings):
    configs = []
    for name in ['Debug','Release']:
        extra = 'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; ENABLE_TESTABILITY = YES;' if name == 'Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O";'
        configs.append(add(key+name,'{isa = XCBuildConfiguration; buildSettings = {'+settings+extra+'}; name = '+name+';}'))
    return add(key+'List','{isa = XCConfigurationList; buildConfigurations = '+arr(configs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}')
common = 'MACOSX_DEPLOYMENT_TARGET = 13.0; SDKROOT = macosx; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES; '
projectConfig = configs('project',common)
appConfig = configs('app','PRODUCT_NAME = PlainPad; PRODUCT_BUNDLE_IDENTIFIER = local.plainpad.editor; INFOPLIST_FILE = Resources/Info.plist; CODE_SIGN_IDENTITY = "-"; CODE_SIGN_STYLE = Manual; COMBINE_HIDPI_IMAGES = YES; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks"; ')
testConfig = configs('test','PRODUCT_NAME = PlainPadTests; PRODUCT_BUNDLE_IDENTIFIER = local.plainpad.editor.tests; GENERATE_INFOPLIST_FILE = YES; CODE_SIGN_IDENTITY = "-"; CODE_SIGN_STYLE = Manual; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) XCODE_TESTS"; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/PlainPad.app/Contents/MacOS/PlainPad"; BUNDLE_LOADER = "$(TEST_HOST)"; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks"; ')
proxy = add('proxy','{isa = PBXContainerItemProxy; containerPortal = '+ident('project')+'; proxyType = 1; remoteGlobalIDString = '+ident('appTarget')+'; remoteInfo = PlainPad;}')
dep = add('dependency','{isa = PBXTargetDependency; target = '+ident('appTarget')+'; targetProxy = '+proxy+';}')
appTarget = add('appTarget','{isa = PBXNativeTarget; buildConfigurationList = '+appConfig+'; buildPhases = '+arr([appSources,frameworks,resources])+'; buildRules = (); dependencies = (); name = PlainPad; productName = PlainPad; productReference = '+appProduct+'; productType = "com.apple.product-type.application";}')
testTarget = add('testTarget','{isa = PBXNativeTarget; buildConfigurationList = '+testConfig+'; buildPhases = '+arr([testSources])+'; buildRules = (); dependencies = '+arr([dep])+'; name = PlainPadTests; productName = PlainPadTests; productReference = '+testProduct+'; productType = "com.apple.product-type.bundle.unit-test";}')
project = add('project','{isa = PBXProject; attributes = {LastUpgradeCheck = 1600;}; buildConfigurationList = '+projectConfig+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = '+mainGroup+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; targets = '+arr([appTarget,testTarget])+';}')
(root/'PlainPad.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = '+v+';' for k,v in objects.items())+'\n}; rootObject = '+project+'; }\n')
scheme = root/'PlainPad.xcodeproj/xcshareddata/xcschemes/PlainPad.xcscheme'; scheme.parent.mkdir(parents=True,exist_ok=True)
def buildref(id,name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{id}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:PlainPad.xcodeproj"/>'
scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildref(appTarget,'PlainPad.app')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{buildref(testTarget,'PlainPadTests.xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref(appTarget,'PlainPad.app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref(appTarget,'PlainPad.app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
