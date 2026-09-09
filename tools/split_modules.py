"""Extract cohesive feature modules with explicit dependencies and shared state.

One-time refactoring helper; generated Luau has no dynamic environment tricks.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r'--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|\b[A-Za-z_]\w*\b')

def identifiers(source, replacements):
    def sub(m):
        name=m[0]
        if name not in replacements: return name
        before=source[:m.start()].rstrip()
        if (before.endswith('.') and not before.endswith('..')) or before.endswith(':'): return name
        return replacements[name]
    return TOKEN.sub(sub,source)

def split(rel, groups, api, states=None):
    p=ROOT/rel
    source=p.read_text(encoding='utf-8')
    matches=list(re.finditer(r'^(?:local )?function ([\w.]+)\(',source,re.M))
    assert matches
    header=source[:matches[0].start()]
    tail_start=source.rfind('\nreturn '+api)
    assert tail_start>0
    blocks={m[1]:source[m.start():matches[i+1].start() if i+1<len(matches) else tail_start].rstrip() for i,m in enumerate(matches)}
    assert set(blocks)=={name for names in groups.values() for name in names}, set(blocks)-{name for names in groups.values() for name in names}
    locals_=re.findall(r'^local (\w+)\s*=',header,re.M)
    if states is None:
        states=[name for name in locals_ if re.search(r'^local '+name+r'\s*=\s*(nil|false|true|\d+)(?:\s|$)',header,re.M) and not name.isupper()]
    functions=[name for name in blocks if '.' not in name]
    replacements={name:'State.'+name for name in states}
    replacements.update({name:'Context.'+name for name in functions})
    for name in states:
        header=re.sub(r'^local '+name+r'\s*=', 'State.'+name+' =',header,flags=re.M)
    header='local State = {}\n'+identifiers(header,{name:'State.'+name for name in states})
    # All values exported here are stable references; mutable scalars live in State.
    deps=[name for name in locals_ if name not in states]
    header+='\nlocal Context = { State = State,\n'+''.join('\t'+name+' = '+name+',\n' for name in deps)+'}\n'
    folder=p.with_suffix('');folder.mkdir(exist_ok=True)
    for group,names in groups.items():
        body='\n\n'.join(blocks[name] for name in names)
        for name in functions:
            body=body.replace('local function '+name+'(', 'function '+name+'(')
        body=identifiers(body,replacements)
        body=identifiers(body,{'script':'script.Parent'})
        used=set(re.findall(r'\b\w+\b',body))
        dependencies=''.join('\tlocal '+name+' = Context.'+name+'\n' for name in deps if name in used)
        text='-- '+group+': focused implementation for '+api+'.\nreturn function(Context)\n\tlocal State = Context.State\n'+dependencies+'\n'+'\n'.join('\t'+line if line else '' for line in body.splitlines())+'\nend\n'
        (folder/(group+'.luau')).write_text(text,encoding='utf-8')
        header+='require(script:WaitForChild("'+group+'"))(Context)\n'
    header+='\nreturn '+api+'\n'
    (folder/'init.luau').write_text(header,encoding='utf-8')
    assert p.resolve().is_relative_to((ROOT/'src').resolve())
    p.unlink()
    print(api, '->', len(groups), 'feature modules')

if __name__=='__main__':
    split('src/client/controllers/ui/UIController.luau', {
        'Navigation':['checkTutorialStatus','UIController.updateTutorialStatus','tweenUIFrame','tweenBlur','tweenCameraFOV','UIController.clearStuckEffects','UIController.openUIFrame','UIController.closeUIFrame','UIController.toggleUIFrame','UIController.flashScreen','UIController.setupNormalUI'],
        'Displays':['formatNumber','formatPopulation','formatNumberShort','updateCashDisplay'],
        'CityPrompts':['createEditPrompt','setupPlotPrompts','UIController.checkAndShowGroupPrompt','setupCityNameUI'],
        'Rebirth':['updateRebirthUI','showRebirthConfirmation','setupRebirthUI','connectRebirthEvents','UIController.initRebirthSystem'],
        'Buttons':['connectButtonEvents','setupTopbarButtons'],
        'DailyRewards':['setupDailyRewardUI'],
        'BuildingActions':['setupBuildingDataUI'],
        'RemoteBindings':['connectRemoteEvents'],
        'Lifecycle':['UIController.init','UIController.cleanup','UIController.getFrames'],
    },'UIController',states=['settingsIcon','playerGui','FramesFolder','ButtonFolder','HUD','rebirthRemotes','currentRebirthData','ShopFrame','SellFrame','ItemShopFrame','SettingsFrame','ConstructionsFrame','GroupRewardFrame','CityNameFrame','BuildingDataFrame','WorldsFrame','RebirthFrame','ConfirmRebirthFrame','confirmYesConnection','confirmNoConnection','currentBuildingToCollect','questUI','deleteButtonConnection','collectButtonConnection','DailyRewardFrame','dailyRewardCountdown','dailyRewardConnection','BuilderPackFrame','weatherFrame','lastRequestTime','currentEditingPlot','UpdateCityNameEvent','currentOpenFrame','isTweening','cashUpdateConnection','comboMultiplier','comboTimer','lastActionTime','isInTutorial','editPrompts'])
    split('src/server/systems/economy/IncomeSystem.luau',{
        'Calculation':['hasDoubleCashGamepass','calculateCrimePenalty','IncomeSystem.ensureBuildingConfig','IncomeSystem.calculatePopulation','IncomeSystem.calculateAndStackBuildingIncome'],
        'Collection':['IncomeSystem.collectPendingIncome','IncomeSystem.resetBuildingIncome','IncomeSystem.clearPlotOwnership','IncomeSystem.setPlotOwnership','handleIncomeCollection'],
        'PlotDisplays':['formatNumberShort','setupUIForPlot','setupUIs','updatePlotUI'],
        'BuildingAlerts':['showBuildingIncomeAlerts'],
        'Lifecycle':['updateIncomeAndPopulationForAllPlayers','IncomeSystem.setupPlayerIncome','IncomeSystem.init'],
    },'IncomeSystem',states=['CityNameSystem'])
    split('src/client/controllers/tutorial/TutorialController.luau',{
        'Highlights':['getPlayerPlot','createTileHighlights','clearTileHighlights'],
        'Subtitles':['updateTutorialText','showcaseShopItems'],
        'Guidance':['createPlayerAnchor','setupBeam','updateBeamTarget','cleanupBeam'],
        'Camera':['setupOrbitCamera','cleanupCameraOrbit','cleanupIncomeHover'],
        'Stages':['connectTutorialEvents','TutorialController.startTutorial'],
        'Lifecycle':['cleanupTutorial','TutorialController.init'],
    },'TutorialController')
    split('src/client/controllers/ui/NotificationController.luau',{
        'Layout':['setupUIListLayout','fadeElements','updateLayoutOrder'],
        'Queue':['removeNotification','cleanupStuckNotifications','NotificationController.showNotification','removeNotificationV2','NotificationController.clearAll'],
        'RemoteBindings':['connectNotificationEvents'],
        'Lifecycle':['NotificationController.init'],
    },'NotificationController')
    split('src/client/controllers/shop/ShopController.luau',{
        'Formatting':['getPriceTier','formatCash','formatTime'],
        'PurchasePanel':['clearButtonConnections','updatePurchaseFrame'],
        'StockDisplay':['createItemFrame','updateShopDisplay'],
        'Lifecycle':['startResetCountdown','ShopController.init'],
    },'ShopController',states=['playerGui','ShopFrame','PurchaseFrameTemplate','ItemTemplate','ItemList','ResetTimerLabel','remainingTime','purchaseDebounce','currentPurchaseFrame','currentPurchaseItem','currentStockList','timerConnection'])
    split('src/server/systems/progression/PostTutorialQuest.luau',{
        'State':['ensureValue','getPlot','isRoad','countPlaced','getPopulation','saveState','loadState'],
        'Progression':['updateUI','giveReward','recalculateProgress','completeQuest','updateProgress'],
        'Objectives':['PostTutorialQuest.onConstructionStarted','PostTutorialQuest.onIncomeCollected','PostTutorialQuest.onBuildingPlaced','PostTutorialQuest.onPopulationChanged'],
        'Lifecycle':['initPlayer','PostTutorialQuest.init'],
    },'PostTutorialQuest',states=[])
