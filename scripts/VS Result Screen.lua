

---@type boolean
ResultScreenDebug = false;

---@type boolean
ResultScreenTrigger = false;

function onCreate()
    addHaxeLibrary("CoolUtil", "backend");
    addHaxeLibrary("CustomFadeTransition", "backend");
    addHaxeLibrary("FlxGradient", "flixel.util");
    addHaxeLibrary("FlxTrail", "flixel.addons.effects");
    addHaxeLibrary("FlxBackdrop", "flixel.addons.display");
    addHaxeLibrary("FlxRect", "flixel.math");
    addHaxeLibrary("ColorTransform", "openfl.geom");
    addHaxeLibrary("FlxColorTransformUtil", "flixel.util");
    addHaxeLibrary("LuaUtils", "psychlua");
    addHaxeLibrary("FlxSubState", "flixel");
    addHaxeLibrary("SScript", "tea");

    RunningUMM = onlinePlay ~= nil;
    -- onlinePlay = true | false
end

---@type any
UnlockedObjectName = nil;
---@type any
UnlockedTitleName = nil;
---@type integer
UnlockedColor = 0x5D3D6F;

function onEvent(name, value1, value2)
    if name == "Signal-Add Unlocked Screen" then
        if not luaSpriteExists(value1) then
            close();
        end

        UnlockedObjectName = value1;
        UnlockedTitleName = (luaSpriteExists(value2) and value2 or nil);
        UnlockedColor = runHaxeCode([[
            return FlxColor.fromInt(CoolUtil.dominantColor(game.modchartSprites.get("]]..value1..[[")));
        ]]);
    elseif name == "Signal-Set Unlocked Screen Color" then
        UnlockedColor = FlxColor(value1);
    elseif name == "Signal-Trigger OVS Results" then
        ResultScreenTrigger = true;
    end
end

---@type boolean
ResultsShown = false;

function onEndSong()
    ResultScreenTrigger = ResultScreenTrigger or not getModSetting("OVSResults-trigger");
    local inTheMiddleOfStory =  getPropertyFromClass("states.PlayState", "storyPlaylist.length") > 1 and isStoryMode;
    if RunningUMM or inTheMiddleOfStory or not ResultScreenTrigger then
        return Function_Continue;
    end
    local substateName = "";
    if not ResultsShown then
        substateName = "ResultScreen";
    elseif UnlockedObjectName ~= nil then
        substateName = "UnlockScreen";
    end
    if substateName ~= "" then
        runHaxeCode([[
            if (CustomSubstate.name != "ResultScreen" && CustomSubstate.name != "UnlockScreen") {
                if (CustomSubstate.instance != null) {
                    CustomSubstate.closeCustomSubstate();
                    FlxG.state.resetSubState();
                }
                FlxG.state.openSubState(new CustomFadeTransition(0.6, false));
                CustomFadeTransition.finishCallback = function() {
                    PlayState.instance.camGame.alpha = 0.0;
                    PlayState.instance.camHUD.alpha = 0.0;
                    PlayState.instance.camOther.alpha = 1.0;
                    FlxG.state.persistentUpdate = false;
                    CustomSubstate.openCustomSubstate("]]..substateName..[[", true);
                };
                CustomFadeTransition.nextCamera = PlayState.instance.camOther;
                FlxG.state.persistentUpdate = true;
            } else {
                CustomSubstate.instance.closeCallback = function() {
                    // If it wasn't for that FUCKING "name = 'unnamed';"
                    // on CustomSubstate's "destroy()" (Why the hell is
                    // it not just on "closeCustomSubstate()"???) I wouldn't
                    // have needed this temp substate.
                    var TempSubstate:FlxSubState = new FlxSubState();
                    TempSubstate.openCallback = function() {
                        CustomSubstate.openCustomSubstate("]]..substateName..[[", true);
                    };
                    FlxG.state.openSubState(TempSubstate);
                };
                CustomSubstate.closeCustomSubstate();
            }
        ]]);
        return Function_Stop;
    end
    closeCustomSubstate();
    return Function_Continue;
end

function onCustomSubstateCreate(name)
    if name == "ResultScreen" then
        SetupResultScreen();

        makeLuaSprite('ResultFadeTransition', "", 0, 0);
        makeGraphic('ResultFadeTransition', screenWidth, screenHeight, "000000");
        setObjectCamera('ResultFadeTransition', "camOther");
        screenCenter('ResultFadeTransition', 'XY');
        insertToCustomSubstate('ResultFadeTransition');
        doTweenAlpha('ResultScreenEnter', 'ResultFadeTransition', 0.0, 0.5, "linear");
    elseif name == "UnlockScreen" then
        SetupUnlockedScreen();

        playSound("woosh", 1);

        doTweenAlpha('BGEnter', 'ResultScreenBG', 1.0, 2, "cubeout");
        doTweenY('RevealUp', 'ResultBlackUp', getProperty('ResultBlackUp.y') - screenHeight/4, 2, "cubeout");
        doTweenY('GRevealUp', 'ResultGradientUp', getProperty('ResultGradientUp.y') - screenHeight/4, 2, "cubeout");
        doTweenY('RevealDown', 'ResultBlackDown', getProperty('ResultBlackDown.y') + screenHeight/4, 2, "cubeout");
        doTweenY('GRevealDown', 'ResultGradientDown', getProperty('ResultGradientDown.y') + screenHeight/4, 2, "cubeout");
        doTweenX('RevealObject', UnlockedObjectName, MiddleX, 2, "cubeout");
        runTimer("WaitText", 1);
    end
end

---@type boolean
AllowExitResults = false;
---@type boolean
CountingAcc = ResultScreenDebug;
---@type number
BGScrollAmount = 0;
---@type number
NumScrollSpeed = 1;

---@type integer
ResultStateKey = 0;
---@type number
AccuracyCounter = (ResultScreenDebug and 0 or -10);
---@type table
ResultScreenStates = {
-- accuracy, rating, BGcolor, pitch, ratingAngle, ratingOffsetX, ratingOffsetY
    {0, "shit", 0x6A4280, -0.35, 8, 3, -3},-- F
    {16, "shit", 0x6A4280, -0.35, 0, 0, 0},-- E
    {32, "bad", 0x6A4280, -0.225, 6, -4, -6},-- D
    {47, "bad", 0x4648AA, -0.1, -4, -3, -4},-- C
    {63, "good", 0x4648AA, 0.0, 3, 31, -6},-- B
    {78, "good", 0xD562E1, 0.15, -7, 31, -6},-- A
    {94, "sick", 0x7EF2BE, 0.25, 9, 58, 3},-- S
    {100, "sick", 0x12E2E2, 0.3, 11, 58, 2},-- Ss
};
SickGoldColor = 0xfEffA4;

---@type table
ResultEnterColors = {{r=51,g=255,b=255}, {r=51,g=51,b=204}};
---@type table
ResultEnterAlphas = {1, 0.64};

function onCustomSubstateUpdate(name, elapsed)
    if name ~= "ResultScreen" then
        return;
    end

    if CountingAcc then
        if ResultScreenDebug then
            if getPropertyFromClass('flixel.FlxG', 'keys.justPressed.SPACE') then
                triggerRankAnimation();
            end
            if getPropertyFromClass('flixel.FlxG', 'keys.pressed.RIGHT') then
                AccuracyCounter = AccuracyCounter + elapsed * 15;
            end
            if getPropertyFromClass('flixel.FlxG', 'keys.pressed.LEFT') then
                AccuracyCounter = AccuracyCounter - elapsed * 15;
            end
            AccuracyCounter = getStateFromKeyboard(true);
        elseif AccuracyCounter < rating * 100 then
            AccuracyCounter = math.min(rating * 100, AccuracyCounter + elapsed * 15 * NumScrollSpeed);
        end

        updateAccuracyCounterText();

        local prvState = ResultStateKey;
        ResultStateKey = getStateFromAccuracyCounter();
        if prvState ~= ResultStateKey then
            loadGraphic('ResultRating', ResultScreenStates[ResultStateKey][2]);
            triggerRankAnimation();
        end

        if ResultScreenDebug then
            setProperty('Screenshots.animation.frameIndex', ResultStateKey-1);
            if getPropertyFromClass('flixel.FlxG', 'keys.justPressed.ENTER') then
                finishCountingAcc();
            end
        elseif AccuracyCounter == rating * 100 then
            finishCountingAcc();
        end
    end

    applyResultScreenFlash();
    easeResultScreenPropertys(elapsed);

    BGScrollAmount = (BGScrollAmount + 60 * elapsed) % getProperty('ResultScreenBG.pixels.width');
    setProperty('ResultScreenBG.offset.x', BGScrollAmount);

    setProperty('ResultMainRank.animation.frameIndex', math.min(6, ResultStateKey-1));
    setProperty('ResultScreenBG.color', ResultScreenStates[ResultStateKey][3]);
    setProperty('ResultSmallS.alpha', (ResultStateKey == 8 and 1.0 or 0.00001));
    setProperty('ResultRating.color', (ResultStateKey == 8 and SickGoldColor or 0xFFFFFF));
    setProperty('ResultRating.angle', ResultScreenStates[ResultStateKey][5]);
    updateHitbox('ResultRating');
    setProperty('ResultRating.offset.x', ResultScreenStates[ResultStateKey][6] +
        getProperty('ResultRating.offset.x') * 0.1);
    setProperty('ResultRating.offset.y', ResultScreenStates[ResultStateKey][7] +
        getProperty('ResultRating.offset.y') * 0.1);
    screenCenter('ResultWhiteGradient', 'XY');
    setProperty('ResultWhiteGradient.x', getProperty('ResultWhiteGradient.x') +
        getProperty('ResultWhiteGradient.frameWidth') - getVar('ResultWhiteRevealed') - 162);
    if getVar('ResultWhiteRevealed') ~= getProperty('ResultWhiteGradient.clipRect.width') then
        runHaxeCode([[
            game.modchartSprites.get("ResultWhiteGradient").clipRect = new FlxRect(0,0,]]..
                getVar('ResultWhiteRevealed')
            ..[[,60);
            // to prevent memory leaks
            SScript.global.clear();
        ]]);
    end

    countStats(elapsed);

    if ResultScreenDebug then
        if getPropertyFromClass('flixel.FlxG', 'keys.justPressed.NINE') then
            setProperty('Screenshots.visible', not getProperty('Screenshots.visible'));
        end
    end

    if AllowExitResults then
        -- f(x) = (1 - cos((x ∙ π) : 1.5)) : 2
        --  		       ↓
        -- 	     local enterLerp = f(x)
        local enterLerp = (1 - math.cos(os.clock() * math.pi/1.5)) / 2;

        setProperty('ResultEnter.color', FlxColor(RGBtoHEX(
            lerp(ResultEnterColors[1].r, ResultEnterColors[2].r, enterLerp),
            lerp(ResultEnterColors[1].g, ResultEnterColors[2].g, enterLerp),
            lerp(ResultEnterColors[1].b, ResultEnterColors[2].b, enterLerp)
        )));
        setProperty('ResultEnter.alpha', lerp(ResultEnterAlphas[1], ResultEnterAlphas[2], enterLerp) * getVar("EnterOpacity"));

        if getPropertyFromClass('flixel.FlxG', 'keys.justPressed.ENTER') then
            setProperty('ResultEnter.color', 0xFFFFFF);
            setProperty('ResultEnter.alpha', 1.0);
            playAnim('ResultEnter', 'pressed');
            playSound("confirmMenu", 1);
            AllowExitResults = false;
            ResultsShown = true;
            runHaxeCode([[
                var TransSubstate:CustomFadeTransition = new CustomFadeTransition(0.6, false);
                // to prevent a softlock where CustomFadeTransition.finishCallbback
                // resets itself (frees itself from memory) and causes itself to stop executing.
                TransSubstate.closeCallback = function() {
                    PlayState.instance.endSong();
                };
                FlxG.state.subState.openSubState(TransSubstate);
                CustomFadeTransition.finishCallback = function() {
                    FlxG.state.subState.persistentUpdate = false;
                    FlxG.state.subState.closeSubState();
                };
                CustomFadeTransition.nextCamera = PlayState.instance.camOther;
                FlxG.state.subState.persistentUpdate = true;
            ]]);
        end
    end

    if (not ResultsShown) and
    (keyPressed('accept') or keyPressed('left') or keyPressed('down') or
    keyPressed('up') or keyPressed('right')) then
        NumScrollSpeed = NumScrollSpeed + 2 * elapsed;
    else
        NumScrollSpeed = 1;
    end
end

function finishCountingAcc()
    CountingAcc = false;
    doTweenAlpha('CounterExit', 'ResultAccCounterFill', 0, 0.25, "linear");
    local accStr = getNumberTextString('ResultAccCounter');
    if accStr == "" then accStr = "0"; end
    setNumberTextString('ResultMainAcc', accStr);
    local accPosX = 36 + (screenWidth - getProperty('ResultMainPercent.frameWidth'))/2;
    doTweenX('MainPercentEnter', 'ResultMainPercent', accPosX, 0.5, "quadout");
    doTweenX('MainAccLineEnter', 'ResultMainAccLine', accPosX, 0.5, "quadout");
    doTweenX('MainAccFillEnter', 'ResultMainAccFill', accPosX, 0.5, "quadout");
    runTimer("ResultRatingEnter", 0.375);
    playSound("cancelMenu", 1);
end

function triggerRankAnimation()
    if ResultStateKey == 1 then
        return;
    end
    playSound("confirmMenu", 1, "RankUp");
    runHaxeCode([[
        game.modchartSounds["RankUp"].pitch = ]]..1 + ResultScreenStates[ResultStateKey][4]..[[;
        // to prevent memory leaks
        SScript.global.clear();
    ]]);
    if ResultStateKey ~= 8 then
        scaleObject('ResultMainRank', 1.15, 1.15, false);
        ResultFlashTable["ResultMainRank"] = 1;
        generateStars();
    else
        playSound("confirmMenu", 1);
    end
    if tonumber(getProperty('ResultScreenBG.color')) ~= ResultScreenStates[ResultStateKey][3] then
        ResultFlashTable["ResultScreenBG"] = 1;
    end
    if ResultStateKey < 7 then
        return;
    end
    cameraFlash("camOther", "FFFFFF", 0.2, true);
end

---@type table
ResultFlashTable = {
    ["ResultMainRank"] = 0,
    ["ResultScreenBG"] = 0,
};

function applyResultScreenFlash()
    for i, v in pairs(ResultFlashTable) do
        if v ~= 0 then
            runHaxeCode([[
                var sprite:FlxSprite = game.getLuaObject("]]..i..[[");
                sprite.color = 0xFFFFFF;
                sprite.updateColorTransform();
                FlxColorTransformUtil.setOffsets(sprite.colorTransform, 0, 0, 0, 0);
                sprite.colorTransform.concat(new ColorTransform(-1, -1, -1, 1, 255, 255, 255));
                sprite.colorTransform.concat(new ColorTransform(]]..1-v..[[, ]]..1-v..[[, ]]..1-v..[[));
                sprite.colorTransform.concat(new ColorTransform(-1, -1, -1, 1, 255, 255, 255));
                // to prevent memory leaks
                SScript.global.clear();
            ]]);
        end
    end
end

---@type table
ResultEaseTable = {
    {"ResultMainRank", ".scale.x", 1, 120},
    {"ResultMainRank", ".scale.y", 1, 120},
    {"ResultMainRank", ".flash", 0, 60},
    {"ResultScreenBG", ".flash", 0, 30},
};

function easeResultScreenPropertys(elapsed)
    for i, v in ipairs(ResultEaseTable) do
        if v[2]:endswith(".flash") then
            if ResultFlashTable[v[1]] ~= v[3] then
                ResultFlashTable[v[1]] = lerp(ResultFlashTable[v[1]], v[3], elapsed * v[4] /
                    (getPropertyFromClass('flixel.FlxG', 'updateFramerate') / 60)
                );
            end
        elseif getProperty(v[1]..v[2]) ~= v[3] then
            setProperty(v[1]..v[2], lerp(getProperty(v[1]..v[2]), v[3], elapsed * v[4] /
                (getPropertyFromClass('flixel.FlxG', 'updateFramerate') / 60)
            ));
        end
    end
end

function generateStars()
    for i = 1, (ResultStateKey-1) * 3 + math.floor((ResultStateKey-1) / 2) * 3 do
        if luaSpriteExists("Star"..i) then
            calibrateStar(i);
        else
            makeLuaSprite("Star"..i, "vsresultscreen/star", 0, 0);
            setObjectCamera("Star"..i, "camOther");
            setProperty("Star"..i..".alpha", 0.5);
            insertToCustomSubstate("Star"..i);

            calibrateStar(i);
        end
    end
end

---@type number
StarAcceleration = -250;
---@type number
StarInitVelocity = 500;

function calibrateStar(i)
    scaleObject("Star"..i, 1, 1, false);
    math.randomseed(os.clock() * i);
    local angle = math.random(0, 360);
    setProperty("Star"..i..".angle", angle);
    setProperty("Star"..i..".x", math.random(
        getProperty("ResultMainRank.x") + getProperty("Star"..i..".frameWidth"),
        getProperty("ResultMainRank.x") + getProperty("ResultMainRank.frameWidth")
        - getProperty("Star"..i..".frameWidth")
    ));
    setProperty("Star"..i..".y", math.random(
        getProperty("ResultMainRank.y") + getProperty("Star"..i..".frameHeight"),
        getProperty("ResultMainRank.y") + getProperty("ResultMainRank.frameHeight")
        - getProperty("Star"..i..".frameHeight")
    ));
    setProperty("Star"..i..".moves", true);
    setProperty("Star"..i..".acceleration.x", math.cos(math.rad(angle)) * StarAcceleration);
    setProperty("Star"..i..".acceleration.y", math.sin(math.rad(angle)) * StarAcceleration);
    setProperty("Star"..i..".velocity.x", math.cos(math.rad(angle)) * StarInitVelocity * (0.5 + math.random()/2));
    setProperty("Star"..i..".velocity.y", math.sin(math.rad(angle)) * StarInitVelocity * (0.5 + math.random()/2));
    doTweenX("Star"..i.."X", "Star"..i..".scale", 0, 0.35, "sineinout");
    doTweenY("Star"..i.."Y", "Star"..i..".scale", 0, 0.35, "sineinout");
end

---@type boolean
CountingStats = false;

---@type number
Topcombo = 0;
function onRecalculateRating()
    Topcombo = math.max(Topcombo, combo);
end

---@type number
ScoreCountSpeed = 2500;
---@type number
TopComboCountSpeed = 10;
---@type number
MissesCountSpeed = 10;

---@type number
ScoreBound = 9;
---@type number
TopComboBound = 3;
---@type number
MissesBound = 3;
---@type number
CharWidth = 88;

---@type boolean
UseDummy = false;
---@type number
ScoreDummy = 1000000000000000000;
---@type number
TopComboDummy = 1000000;
---@type number
MissesDummy = 1000000;

function countStats(elapsed)
    if not CountingStats then
        return;
    end

    math.randomseed(os.clock());

    local score = (UseDummy and ScoreDummy or (isStoryMode and getProperty("campaignScore") or score));
    local Topcombo = (UseDummy and TopComboDummy or Topcombo);
    local misses = (UseDummy and MissesDummy or (isStoryMode and getProperty("campaignMisses") or misses));

    local curScoreStr = getNumberTextString('ResultScoreText');
    curScoreStr = (curScoreStr == "" and "0" or curScoreStr);
    local curTopComboStr = getNumberTextString('ResultTopComboText');
    curTopComboStr = (curTopComboStr == "" and "0" or curTopComboStr);
    local curMissesStr = getNumberTextString('ResultMissesText');
    curMissesStr = (curMissesStr == "" and "0" or curMissesStr);

    local nextScoreCount = math.min(score, tonumber(curScoreStr) +
        (ScoreCountSpeed^(NumScrollSpeed)) * math.random() * 60 * elapsed);
    local nextTopComboCount =  math.min(Topcombo, tonumber(curTopComboStr) +
        (TopComboCountSpeed^(NumScrollSpeed)) * math.random() * 60 * elapsed);
    local nextMissesCount = math.min(misses, tonumber(curMissesStr) +
        (MissesCountSpeed^(NumScrollSpeed)) * math.random() * 60 * elapsed);
    
    setNumberTextString('ResultScoreText', string.format("%d", math.floor(nextScoreCount)));
    setNumberTextString('ResultTopComboText', string.format("%d", math.floor(nextTopComboCount)));
    setNumberTextString('ResultMissesText', string.format("%d", math.floor(nextMissesCount)));

    curScoreStr = getNumberTextString('ResultScoreText');
    curTopComboStr = getNumberTextString('ResultTopComboText');
    curMissesStr = getNumberTextString('ResultMissesText');

    setNumberTextWidth('ResultScoreText', #curScoreStr * CharWidth);
    setProperty('ResultScore.offset.x', math.min(0, ScoreBound - #curScoreStr) * CharWidth/2);
    setProperty('ResultScoreTextLine.offset.x', (math.min(ScoreBound , #curScoreStr) -
        math.min(0, ScoreBound - #curScoreStr)/2) * CharWidth);
    setProperty('ResultScoreTextFill.offset.x', (math.min(ScoreBound , #curScoreStr) -
        math.min(0, ScoreBound - #curScoreStr)/2) * CharWidth);

    setNumberTextWidth('ResultMissesText', #curMissesStr * CharWidth);
    setProperty('ResultMisses.offset.x', math.min(0, MissesBound - #curMissesStr) * CharWidth/2);
    setProperty('ResultMissesTextLine.offset.x', (math.min(MissesBound , #curMissesStr) -
        math.min(0, MissesBound - #curMissesStr)/2) * CharWidth);
    setProperty('ResultMissesTextFill.offset.x', (math.min(MissesBound , #curMissesStr) -
        math.min(0, MissesBound - #curMissesStr)/2) * CharWidth);

    setNumberTextWidth('ResultTopComboText', #curTopComboStr * CharWidth);
    setProperty('ResultTopCombo.offset.x', math.min(0, TopComboBound - #curTopComboStr +
        math.min(0, MissesBound - #curMissesStr)) * CharWidth/2);
    setProperty('ResultTopComboTextLine.offset.x', (math.min(TopComboBound + math.min(0, MissesBound - #curMissesStr), #curTopComboStr) -
        math.min(0, TopComboBound - #curTopComboStr + math.min(0, MissesBound - #curMissesStr))/2) * CharWidth);
    setProperty('ResultTopComboTextFill.offset.x', (math.min(TopComboBound + math.min(0, MissesBound - #curMissesStr), #curTopComboStr) -
        math.min(0, TopComboBound - #curTopComboStr + math.min(0, MissesBound - #curMissesStr))/2) * CharWidth);

    if nextScoreCount >= score and nextTopComboCount >= Topcombo and nextMissesCount >= misses then
        CountingStats = false;
    end
end

function getStateFromKeyboard(toAccuracy)
    local key = runHaxeCode('return FlxG.keys.firstJustPressed();') - 48;
    if toAccuracy then
        return  ((key > 0 and key < 9) and ResultScreenStates[key][1] or AccuracyCounter);
    end
    return ((key > 0 and key < 9) and key or ResultStateKey);
end

function getStateFromAccuracyCounter()
    local result = 1;
    for i, v in ipairs(ResultScreenStates) do
        if AccuracyCounter >= v[1] then
            result = i;
        else
            break;
        end
    end
    return result;
end

function updateAccuracyCounterText()
    local prvStr = getNumberTextString('ResultAccCounter');
    local prvAcc = (prvStr == "" and 0 or tonumber(prvStr));
    if math.max(0,math.floor(AccuracyCounter)) == prvAcc then
        return;
    end
    playSound("scrollMenu", 1/NumScrollSpeed);
    setNumberTextString('ResultAccCounter',
        (math.floor(AccuracyCounter) <= 0 and "" or tostring(math.floor(AccuracyCounter)))
    );
end

function onTimerCompleted(tag, loops, loopsLeft)

--------------------------------------------------------
-- Result Screen Timers
--------------------------------------------------------
    if tag == "ResultRatingEnter" then
        setProperty('ResultRating.alpha', 1.0);
        scaleObject('ResultRating', 9, 9, false);
        doTweenX('ResultRatingScaleX', 'ResultRating.scale', 1, 0.125, "cubein");
        doTweenY('ResultRatingScaleY', 'ResultRating.scale', 1, 0.125, "cubein");
    elseif tag == "ResultShowMore" then
        AllowExitResults = true;
        table.insert(ResultEaseTable,{"EnterOpacity", "", 1, 10});
        playSound("cancelMenu", 1);
        doTweenX('EnterScore', 'ResultScore',
            (screenWidth - getProperty('ResultScore.width'))/2 - 108, 0.5, 'quadout');
        doTweenX('EnterTopCombo', 'ResultTopCombo',
            (screenWidth - getProperty('ResultTopCombo.width'))/2 - 47, 0.5, 'quadout');
        doTweenX('EnterMisses', 'ResultMisses',
            (screenWidth - getProperty('ResultMisses.width'))/2 - 369, 0.5, 'quadout');
--------------------------------------------------------
-- Unlocked Screen Timers
--------------------------------------------------------

    elseif tag == "WaitText" then
        doTweenY('RevealText', 'UnlockedText', 20, 0.5, "quadout");
        runTimer("HideText", 1.5);
    elseif tag == "HideText" then
        doTweenY('HideText', 'UnlockedText', -233, 1, "cubeout");
    elseif tag == "HideBG" then
        doTweenAlpha('BGExit', 'ResultScreenBG', 0.0, 1.5, "cubein");
        doTweenY('HideUp', 'ResultBlackUp', getProperty('ResultBlackUp.y') + screenHeight/4, 1.5, "cubein");
        doTweenY('GHideUp', 'ResultGradientUp', getProperty('ResultGradientUp.y') + screenHeight/4, 1.5, "cubein");
        doTweenY('HideDown', 'ResultBlackDown', getProperty('ResultBlackDown.y') - screenHeight/4, 1.5, "cubein");
        doTweenY('GHideDown', 'ResultGradientDown', getProperty('ResultGradientDown.y') - screenHeight/4, 1.5, "cubein");
        doTweenX('HideObject', UnlockedObjectName, -(getProperty(UnlockedObjectName..'.frameWidth') + screenWidth/2) +
            getProperty(UnlockedObjectName..'.offset.x'), 1.5, "cubein");
        if UnlockedTitleName ~= nil then
            doTweenX('HideTitle', UnlockedTitleName, getProperty(UnlockedTitleName..'.frameWidth') + screenWidth * 1.5 +
                getProperty(UnlockedObjectName..'.offset.x'), 1.25, "cubein");
        end
    end
end

function onTweenCompleted(tag)

--------------------------------------------------------
-- Result Screen Tweens
--------------------------------------------------------

    if tag:startswith("Star") then
        setProperty(tag:sub(1,-2)..".moves", false);
    elseif tag == "ResultScreenEnter" then
        if not ResultScreenDebug then
            CountingAcc = true;
        end
    elseif tag == "CounterExit" then
        table.insert(ResultEaseTable,{"ResultWhiteRevealed", "",
        getProperty('ResultWhiteGradient.frameWidth'), 30});
    elseif tag == "ResultRatingScaleX" then
        playSound("confirmMenu", 1);
        cameraFlash("camOther", "#88FFFFFF", 0.1, true);
        cameraShake("camOther", 0.01, 0.3);
        runTimer("ResultShowMore", 1);
    elseif tag == "EnterScore" then
        CountingStats = true;
--------------------------------------------------------
-- Unlocked Screen Tweens
--------------------------------------------------------

    elseif tag == "RevealText" then
        cameraFlash("camOther", "FFFFFF", 0.2, false);
        cameraShake("camOther", 0.003, 0.3);
        playSound("unlocksound", 1);

        if UnlockedTitleName == nil then
            setProperty(UnlockedObjectName..'.color', 0xFFFFFF);
            setProperty('UnlockedTrail.color', 0xFFFFFF);
        else
            setProperty(UnlockedTitleName..'.alpha', 1.0);
        end
        
        runTimer("HideBG", 1.25);
    elseif tag == "BGExit" then
        UnlockedObjectName = nil;
        endSong();
    end
end

function SetupResultScreenBG()

    runHaxeCode('setVar("ResultScreenBG", new FlxBackdrop(Paths.image("menuDesat")));');
    setObjectCamera('ResultScreenBG', "camOther");
    screenCenter('ResultScreenBG', 'XY');
    setProperty('ResultScreenBG.offset.y', -5);
    setProperty('ResultScreenBG.color', 0x6A4280);
    setProperty('ResultScreenBG.alpha', 1);

    makeLuaSprite('ResultBlackUp', "", 0, 0);
    makeGraphic('ResultBlackUp', screenWidth, screenHeight/2, "000000");
    setObjectCamera('ResultBlackUp', "camOther");
    screenCenter('ResultBlackUp', 'XY');
    setProperty('ResultBlackUp.y', getProperty('ResultBlackUp.y') - screenHeight * 0.55);

    makeLuaSprite('ResultBlackDown', "", 0, 0);
    makeGraphic('ResultBlackDown', screenWidth, screenHeight/2, "000000");
    setObjectCamera('ResultBlackDown', "camOther");
    screenCenter('ResultBlackDown', 'XY');
    setProperty('ResultBlackDown.y', getProperty('ResultBlackDown.y') + screenHeight * 0.55);

    makeLuaSprite('ResultGradientUp', "", 0, 0);
    setObjectCamera('ResultGradientUp', "camOther");
    runHaxeCode([[
        game.modchartSprites.get("ResultGradientUp").pixels = 
            FlxGradient.createGradientBitmapData(1, FlxG.height * 0.3, [FlxColor.BLACK, 0xDB000000,
            0xA0000000, 0x60000000, 0x22000000, FlxColor.TRANSPARENT]);
    ]]);
    setProperty('ResultGradientUp.scale.x', screenWidth);
    screenCenter('ResultGradientUp', 'XY');
    setProperty('ResultGradientUp.y', getProperty('ResultGradientUp.y') - screenHeight * 0.15);

    makeLuaSprite('ResultGradientDown', "", 0, 0);
    setObjectCamera('ResultGradientDown', "camOther");
    runHaxeCode([[
        game.modchartSprites.get("ResultGradientDown").pixels = 
            FlxGradient.createGradientBitmapData(1, FlxG.height * 0.3, [FlxColor.TRANSPARENT, 0x22000000,
            0x60000000, 0xA0000000, 0xDB000000, FlxColor.BLACK]);
    ]]);
    setProperty('ResultGradientDown.scale.x', screenWidth);
    screenCenter('ResultGradientDown', 'XY');
    setProperty('ResultGradientDown.y', getProperty('ResultGradientDown.y') + screenHeight * 0.15);

    insertToCustomSubstate('ResultScreenBG');
    insertToCustomSubstate('ResultBlackUp');
    insertToCustomSubstate('ResultBlackDown');
    insertToCustomSubstate('ResultGradientUp');
    insertToCustomSubstate('ResultGradientDown');
end

function SetupResultScreen()
    SetupResultScreenBG();

    makeLuaSprite('ResultWhiteGradient', "", 0, 0);
    setObjectCamera('ResultWhiteGradient', "camOther");
    runHaxeCode([[
        game.modchartSprites.get("ResultWhiteGradient").pixels = 
            FlxGradient.createGradientBitmapData(956, 1, [FlxColor.WHITE, 0xDDFFFFFF,
            0xAAFFFFFF, 0x77FFFFFF, 0x33FFFFFF, 0x00FFFFFF], 1, 180);
    ]]);
    setProperty('ResultWhiteGradient.scale.y', 60);
    updateHitbox('ResultWhiteGradient');
    screenCenter('ResultWhiteGradient', 'XY');
    setVar('ResultWhiteRevealed', 0);
    setProperty('ResultWhiteGradient.x', getProperty('ResultWhiteGradient.x') +
        getProperty('ResultWhiteGradient.frameWidth') - getVar('ResultWhiteRevealed') - 162);
    runHaxeCode('game.modchartSprites.get("ResultWhiteGradient").clipRect = new FlxRect(0,0,'..
        getVar('ResultWhiteRevealed')
    ..',60);');

    makeLuaSprite('ResultSmallS', 'vsresultscreen/smallS', 0, 0);
    setObjectCamera('ResultSmallS', "camOther");
    screenCenter('ResultSmallS', 'XY');
    setProperty('ResultSmallS.y', getProperty('ResultSmallS.y') + 118);
    setProperty('ResultSmallS.x', getProperty('ResultSmallS.x') + 530);
    setProperty('ResultSmallS.alpha', 0.00001);

    makeAnimatedLuaSprite('ResultMainRank', 'vsresultscreen/ranks', 0, 0);
    addAnimationByPrefix('ResultMainRank', 'ranks', 'ranks', 0, false);
    playAnim('ResultMainRank', 'ranks');
    setObjectCamera('ResultMainRank', "camOther");
    screenCenter('ResultMainRank', 'XY');
    setProperty('ResultMainRank.y', getProperty('ResultMainRank.y') + 21);
    setProperty('ResultMainRank.x', getProperty('ResultMainRank.x') + 275);

    makeNumberText('ResultAccCounter', 150,
        getProperty('ResultMainRank.x') + 145,
        getProperty('ResultMainRank.y') - 45,
        false
    );

    setProperty('ResultAccCounterFill.alpha', 0.6);

    -- makeLuaSprite('ResultMainCrown', 'vsresultscreen/crown', 0, 0);
    -- setObjectCamera('ResultMainCrown', "camOther");
    -- screenCenter('ResultMainCrown', 'XY');
    -- setProperty('ResultMainCrown.y', getProperty('ResultMainRank.y') + 27.5);
    -- setProperty('ResultMainCrown.x', getProperty('ResultMainRank.x') + 112.5);
    -- setProperty('ResultMainCrown.angle', -20);
    -- setProperty('ResultMainCrown.alpha', 0.00001);

    makeLuaSprite('ResultMainPercent', 'vsresultscreen/percent', 0, 0);
    setObjectCamera('ResultMainPercent', "camOther");
    screenCenter('ResultMainPercent', 'Y');
    setProperty('ResultMainPercent.y', getProperty('ResultMainPercent.y') - 2);
    setProperty('ResultMainPercent.x', -getProperty('ResultMainPercent.frameWidth'));

    makeNumberText('ResultMainAcc', 150, getProperty('ResultMainPercent.x'), getProperty('ResultMainPercent.y'), false);
    setProperty('ResultMainAccFill.offset.x', 155);
    setProperty('ResultMainAccLine.offset.x', 155);

    makeAnimatedLuaSprite('ResultScore', 'vsresultscreen/stats', 0, 0);
    addAnimationByPrefix('ResultScore', 'score', 'Score', 24, true);
    setObjectCamera('ResultScore', "camOther");
    screenCenter('ResultScore', 'Y');
    setProperty('ResultScore.y', getProperty('ResultScore.y') + 72);
    setProperty('ResultScore.x', -getProperty('ResultScore.frameWidth'));

    makeNumberText('ResultScoreText', 150, -128, 72, true);

    makeAnimatedLuaSprite('ResultTopCombo', 'vsresultscreen/stats', 0, 0);
    addAnimationByPrefix('ResultTopCombo', 'topcombo', 'TopCombo', 24, true);
    setObjectCamera('ResultTopCombo', "camOther");
    screenCenter('ResultTopCombo', 'Y');
    setProperty('ResultTopCombo.y', getProperty('ResultTopCombo.y') + 166);
    setProperty('ResultTopCombo.x', -getProperty('ResultTopCombo.frameWidth'));

    makeNumberText('ResultTopComboText', 150, -67, 166, true);

    makeAnimatedLuaSprite('ResultMisses', 'vsresultscreen/stats', 0, 0);
    addAnimationByPrefix('ResultMisses', 'misses', 'Misses', 24, true);
    setObjectCamera('ResultMisses', "camOther");
    screenCenter('ResultMisses', 'Y');
    setProperty('ResultMisses.y', getProperty('ResultMisses.y') + 164);
    setProperty('ResultMisses.x', -getProperty('ResultMisses.frameWidth'));

    makeNumberText('ResultMissesText', 150, -389, 164, true);

    makeLuaSprite('ResultRating', 'shit', 0, 0);
    setObjectCamera('ResultRating', "camOther");
    screenCenter('ResultRating', 'XY');
    setProperty('ResultRating.y', getProperty('ResultRating.y') - 113);
    setProperty('ResultRating.x', getProperty('ResultRating.x') - 115);
    setProperty('ResultRating.alpha', 0.00001);

    makeAnimatedLuaSprite('ResultEnter', 'titleEnter', 0, 0);
    addAnimationByPrefix('ResultEnter', 'idle', 'ENTER IDLE', 0, false);
    addAnimationByPrefix('ResultEnter', 'pressed', 'ENTER PRESSED', 12, true);
    playAnim('ResultEnter', 'idle');
    runHaxeCode('game.modchartSprites.get("ResultEnter").clipRect = new FlxRect(0,0,592,271);');
    setObjectCamera('ResultEnter', "camOther");
    scaleObject('ResultEnter', 0.84, 0.84, false);
    screenCenter('ResultEnter', 'XY');
    setProperty('ResultEnter.y', getProperty('ResultEnter.y') + screenHeight/2 - 59);
    setProperty('ResultEnter.x', getProperty('ResultEnter.x') - screenWidth/2 + 655);
    setProperty('ResultEnter.color', 0x33FFFF);
    setProperty('ResultEnter.alpha', 0.00001);
    setVar("EnterOpacity", 0);

    insertToCustomSubstate('ResultWhiteGradient');
    insertToCustomSubstate('ResultSmallS');
    insertNumberTextToCustomSubstate('ResultAccCounter');
    insertToCustomSubstate('ResultMainRank');
    -- insertToCustomSubstate('ResultMainCrown');
    insertNumberTextToCustomSubstate('ResultMainAcc');
    insertToCustomSubstate('ResultMainPercent');
    insertNumberTextToCustomSubstate('ResultScoreText');
    insertToCustomSubstate('ResultScore');
    insertNumberTextToCustomSubstate('ResultTopComboText');
    insertToCustomSubstate('ResultTopCombo');
    insertNumberTextToCustomSubstate('ResultMissesText');
    insertToCustomSubstate('ResultMisses');
    insertToCustomSubstate('ResultEnter');
    insertToCustomSubstate('ResultRating');

    if not ResultScreenDebug then
        return;
    end

    makeAnimatedLuaSprite('Screenshots', 'vsresultscreen/screenshots', 0, 0);
    addAnimationByPrefix('Screenshots', 'screenshots', 'screens', 0, false);
    playAnim('Screenshots', 'screenshots');
    setObjectCamera('Screenshots', "camOther");
    screenCenter('Screenshots', 'XY');
    setProperty('Screenshots.alpha', 0.3);
    setProperty('Screenshots.visible', false);

    insertToCustomSubstate('Screenshots');
end

---Creates all the necessary sprites for the unlocked screen
function SetupUnlockedScreen()
    -- create the background sprites
    -- and add them to the substate
    SetupResultScreenBG();
    
    -- Setup the background image for the unlocked screen
    setProperty('ResultScreenBG.color', UnlockedColor);
    scaleObject('ResultScreenBG', 1.125, 1.125, false);
    setProperty('ResultScreenBG.offset.y', 12);
    setProperty('ResultScreenBG.offset.x', 37);
    screenCenter('ResultScreenBG', 'XY');
    setProperty('ResultScreenBG.alpha', 0.00001);
    -- Calibrate the scroll amount variable,
    -- so if it starts scrolling again, it'll
    -- start from the beginning (no that there's
    -- a reason for that to happen anyway...)
    BGScrollAmount = 0;

    -- Reset the upper black bar's position.
    -- (It should start on the upper half of the screen)
    screenCenter('ResultBlackUp', 'XY');
    setProperty('ResultBlackUp.y', getProperty('ResultBlackUp.y') - screenHeight/4);

    -- Reset the lower black bar's position.
    -- (It should start on the lower half of the screen)
    screenCenter('ResultBlackDown', 'XY');
    setProperty('ResultBlackDown.y', getProperty('ResultBlackDown.y') + screenHeight/4);

    -- Reset the upper gradient and it's position.
    -- (It should be a smaller and simpler gradient,
    -- and it should start below the upper black bar)
    runHaxeCode([[
        game.modchartSprites.get("ResultGradientUp").pixels = 
            FlxGradient.createGradientBitmapData(1, FlxG.height * 0.075, [FlxColor.BLACK, FlxColor.TRANSPARENT]);
    ]]);
    setProperty('ResultGradientUp.scale.x', screenWidth);
    screenCenter('ResultGradientUp', 'XY');
    setProperty('ResultGradientUp.y', getProperty('ResultGradientUp.y') + screenHeight * 0.0375);

    -- Reset the lower gradient and it's position.
    -- (It should be a smaller and simpler gradient,
    -- and it should start above the lower black bar)
    runHaxeCode([[
        game.modchartSprites.get("ResultGradientDown").pixels = 
            FlxGradient.createGradientBitmapData(1, FlxG.height * 0.075, [FlxColor.TRANSPARENT, FlxColor.BLACK]);
    ]]);
    setProperty('ResultGradientDown.scale.x', screenWidth);
    screenCenter('ResultGradientDown', 'XY');
    setProperty('ResultGradientDown.y', getProperty('ResultGradientDown.y') - screenHeight * 0.0375);

    -- Using the provided sprite tag, we adjust
    -- the unlocked object's properties to make
    -- it fit in the unlocked screen.
    -- (It should start off-screen and later,
    -- it should move to the center from the
    -- right and then move back off-screen
    -- to the left)
    setObjectCamera(UnlockedObjectName, "camOther");
    screenCenter(UnlockedObjectName, 'XY');
    -- We save the middle x position of the object
    -- to know where to move it back later
    MiddleX = getProperty(UnlockedObjectName..'.x');
    setProperty(UnlockedObjectName..'.x', getProperty(UnlockedObjectName..'.x') + screenWidth/2 +
        getProperty(UnlockedObjectName..'.frameWidth') + getProperty(UnlockedObjectName..'.offset.x'));
    setProperty(UnlockedObjectName..'.alpha', 1.0);
    setProperty(UnlockedObjectName..'.visible', true);
    if UnlockedTitleName == nil then
        -- If a title sprite wasn't provided
        -- along side the object sprite,
        -- It'll start black and will
        -- later become visible.
        setProperty(UnlockedObjectName..'.color', 0x000000);
    else
        -- If a title sprite was provided
        -- along side the object sprite,
        -- we adjust it's properties to make
        -- it fit in the unlocked screen.
        -- (It should start invisible in the
        -- bottom-right corner and later, it
        -- should become visible and move
        -- off-screen to the right)
        setObjectCamera(UnlockedTitleName, "camOther");
        screenCenter(UnlockedTitleName, 'XY');
        setProperty(UnlockedTitleName..'.x', getProperty(UnlockedTitleName..'.x') + screenWidth/4);
        setProperty(UnlockedTitleName..'.y', getProperty(UnlockedTitleName..'.y') + screenHeight/4);
        setProperty(UnlockedTitleName..'.alpha', 0.00001);
        setProperty(UnlockedTitleName..'.visible', true);
    end

    -- Create the text sprite for the unlocked screen.
    -- (Always reads "You have UNLOCKED", starts off-screen
    -- and later, it should move to the upper-left corner
    -- of the screen and then move back off-screen)
    makeLuaSprite('UnlockedText', 'vsresultscreen/unlocked', 50, -233);
    setObjectCamera('UnlockedText', "camOther");

    -- Create a trail efect for
    -- the unlocked object sprite.
    -- (Uses FlxTrail from the
    -- flixel.addons.effects package)
    runHaxeCode([[
        var object:FlxSprite = game.modchartSprites.get("]]..UnlockedObjectName..[[");
        var trail:FlxTrail = new FlxTrail(object, null, 6, ]]..
        math.ceil((getPropertyFromClass('backend.ClientPrefs', 'data.framerate') / 60) * 1.25)
        ..[[, 0.25, 0.05);
        setVar("UnlockedTrail", trail);
    ]]);
    setObjectCamera('UnlockedTrail', "camOther");
    -- If a title sprite wasn't provided
    -- along side the object sprite,
    -- It'll start black and will
    -- later become visible.
    if UnlockedTitleName == nil then
        setProperty('UnlockedTrail.color', 0x000000);
    end

    -- We add all the sprites
    -- we just created to the
    -- screen in the right order
    insertToCustomSubstate('UnlockedTrail');
    insertToCustomSubstate(UnlockedObjectName);
    if UnlockedTitleName ~= nil then
        insertToCustomSubstate(UnlockedTitleName);
    end
    insertToCustomSubstate('UnlockedText');
end


------------------------------------------------------------------------------
-- Number Text Functions
------------------------------------------------------------------------------


function makeNumberText(tag, width, x, y, center)
    makeLuaText(tag..'Line', "", width, 0, 0);
    setObjectCamera(tag..'Line', "camOther");
    setTextFont(tag..'Line', 'vsresultscreen/fnf-num-line.ttf');
    setTextAlignment(tag..'Line', 'right');
    setProperty(tag..'Line.wordWrap', false);
    setTextSize(tag..'Line', 65);
    setBlendMode(tag..'Line', 'MULTIPLY');
    setTextBorder(tag..'Line', 0, '000000');
    setTextColor(tag..'Line', '000000');
    if center then
        screenCenter(tag..'Line', 'XY');
        setProperty(tag..'Line.y', getProperty(tag..'Line.y') + y);
        setProperty(tag..'Line.x', getProperty(tag..'Line.x') + x);
    else
        setProperty(tag..'Line.y', y);
        setProperty(tag..'Line.x', x);
    end

    makeLuaText(tag..'Fill', "", width, 0, 0);
    setObjectCamera(tag..'Fill', "camOther");
    setTextFont(tag..'Fill', 'vsresultscreen/fnf-num-fill.ttf');
    setTextAlignment(tag..'Fill', 'right');
    setProperty(tag..'Fill.wordWrap', false);
    setTextSize(tag..'Fill', 65);
    setTextBorder(tag..'Fill', 0, '000000');
    setTextColor(tag..'Fill', 'FFFFFF');
    screenCenter(tag..'Fill', 'XY');
    setProperty(tag..'Fill.y', getProperty(tag..'Line.y'));
    setProperty(tag..'Fill.x', getProperty(tag..'Line.x'));
end

function insertNumberTextToCustomSubstate(tag, pos)
    insertLuaTextToCustomSubstate(tag..'Fill', pos);
    insertLuaTextToCustomSubstate(tag..'Line', pos);
end

function insertLuaTextToCustomSubstate(tag, pos)
    runHaxeCode([[
        setVar("TempTextLua", LuaUtils.getTextObject("]]..tag..[["));
    ]]);
    insertToCustomSubstate('TempTextLua', pos);
    setVar("TempTextLua", nil);
end

function setNumberTextWidth(tag, width)
    setTextWidth(tag..'Line', width);
    setTextWidth(tag..'Fill', width);
end

function getNumberTextWidth(tag)
    return getTextWidth(tag..'Line');
end

function setNumberTextString(tag, str)
    setTextString(tag..'Line', str);
    setTextString(tag..'Fill', str);
end

function getNumberTextString(tag)
    return getTextString(tag..'Line');
end


-- short for linear interpolation
function lerp(a, b, ratio)
    return a + (b - a) * ratio;
end

--- takes RGB color values
--- and turns them into
--- HEX #RRGGBB format.
---@param r number The red value
---@param g number The green value
---@param b number The blue value
function RGBtoHEX(r, g, b)
	-- string.format explanation: https://www.lua.org/pil/20.html#:~:text=The%20function-,string.format,-is%20a%20powerful
	return string.format("#%02x%02x%02x", r, g, b);
end

--- Checks if a string ends with a curtain
--- sequence of characters
---@param self string The string that needs to be checked
---@param ends string A string value of the sequence of characters that needs to be checked from the end
function string:endswith(ends)
    -- string.sub() explanation: https://www.lua.org/pil/20.html#:~:text=The%20call-,string.sub,-(s%2Ci%2Cj
    -- # - the length of an table(array) / string
    return self:sub(-#ends) == ends;
end
-- this function is being added to the string library/module

--- Checks if a string starts with a curtain
--- sequence of characters
---@param self string The string that needs to be checked
---@param start string A string value of the sequence of characters that needs to be checked from the start
---@diagnostic disable-next-line: duplicate-set-field
function string:startswith(start)
    -- string.sub() explanation: https://www.lua.org/pil/20.html#:~:text=The%20call-,string.sub,-(s%2Ci%2Cj
    -- # - the length of an table(array) / string
    return self:sub(1, #start) == start;
end
-- this function is being added to the string library/module