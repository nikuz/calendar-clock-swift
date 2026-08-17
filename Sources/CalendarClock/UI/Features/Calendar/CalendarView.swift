import Foundation
import CRayLib

@MainActor
enum CalendarView {
    private enum CalendarStateKey: Equatable {
        case loading
        case loaded(UInt64) // layout revision
        case failed
    }

    /// Everything the scene is drawn from. While it stays the same, and nothing
    /// on the screen is animated, the previously rendered frame is still valid.
    private struct RenderState: Equatable {
        let calendar: CalendarStateKey
        let totalMinutes: Int
        let isNightTime: Bool
        let dayBrightness: Float
        let nightBrightness: Float
        let backgroundVisible: Bool
        let activeEventId: String?
        let flashingEventId: String?
        let confirmedApproachingEventId: String?
        let flashPhase: Int
        let navigationEventIndex: Int?
        let navigationShift: Float
        let selectedEventIndex: Int?

        /// The scene draws an animation, every frame of it is different
        var isAnimated: Bool {
            if isNightTime {
                return false
            }

            switch calendar {
                case .loading:
                    // animated loading indicator
                    return true
                case .loaded:
                    // the alarm wave effect is animated until the event is confirmed
                    return activeEventId != nil && activeEventId != confirmedApproachingEventId
                case .failed:
                    return false
            }
        }

        init(
            time: CalendarUIUtils.TimeInfo,
            isNightTime: Bool,
            appState: AppStateData,
            eventsOrder: CalendarUIUtils.EventsOrder,
            eventsNavigation: CalendarUIUtils.EventsNavigation?,
            selectedEventIndex: Int?,
        ) {
            let confirmedApproachingEventId = appState.calendar.confirmedApproachingEventId
            let flashingEventId = (eventsOrder.approachingEvent ?? eventsOrder.activeEvent)?.event.id

            switch appState.calendar {
                case .loading: calendar = .loading
                case .loaded(let payload): calendar = .loaded(payload.layoutRevision)
                case .failed: calendar = .failed
            }

            self.isNightTime = isNightTime
            self.confirmedApproachingEventId = confirmedApproachingEventId
            self.flashingEventId = flashingEventId
            self.selectedEventIndex = selectedEventIndex
            totalMinutes = time.totalMinutes
            dayBrightness = appState.brightness.dayFactor
            nightBrightness = appState.brightness.nightFactor
            backgroundVisible = appState.backgroundVisible
            activeEventId = eventsOrder.activeEvent?.event.id
            navigationEventIndex = eventsNavigation?.eventIndex
            navigationShift = eventsNavigation?.shift ?? 0
            // the flashing event card only changes twice per second
            flashPhase = flashingEventId != nil && flashingEventId != confirmedApproachingEventId
                ? time.second % 2
                : -1
        }
    }

    // static private let animationDuration = 1.0 // seconds
    // static private var animationStartTime = GetTime()
    // static private var animationDirection: Float = 1
    static private var eventsCards: [CalendarEventCardComponent?] = []
    static private var eventsCardsRevision: UInt64?
    static private var eventsNavigation: CalendarUIUtils.EventsNavigation?
    static private var selectedEventIndex: Int?
    static private var eventsOrder: CalendarUIUtils.EventsOrder = (nil, nil, nil, nil)
    static private var eventsOrderMinutes: Int = -1
    static private var eventsOrderRevision: UInt64?
    static private var lastRenderState: RenderState?

    static func render(appState: AppState, hiddenEventsStore: HiddenEventsStore) {
        let frameStartTime = GetTime()
        let time = CalendarUIUtils.getTime()
        let isNightTime = CalendarUIUtils.isNightTime(time)

        var _appState = appState.current

        // keyboard shortcuts and the alarm sound are handled on every frame,
        // even when the scene doesn't have to be re-rendered
        if !isNightTime, case .loaded(let payload) = _appState.calendar {
            updateEventsOrder(payload: payload, time: time)
            handleKeyboardShortcuts(
                appState: appState,
                hiddenEventsStore: hiddenEventsStore,
                payload: payload,
                time: time,
            )
            // shortcuts can change the state, the scene has to be drawn from the new one
            _appState = appState.current
            // hiding an event takes it out of the order, the alarm must not ring for it
            if case .loaded(let updatedPayload) = _appState.calendar {
                updateEventsOrder(payload: updatedPayload, time: time)
            }
            CalendarActiveEventAlarm.play(appState: _appState, eventsOrder: eventsOrder)
        } else {
            resetEventsOrder()
        }

        let renderState = RenderState(
            time: time,
            isNightTime: isNightTime,
            appState: _appState,
            eventsOrder: eventsOrder,
            eventsNavigation: eventsNavigation,
            selectedEventIndex: selectedEventIndex,
        )

        // the previous frame is still on the screen and it's still valid
        guard renderState != lastRenderState || renderState.isAnimated else {
            skipFrame(frameStartTime: frameStartTime)
            return
        }
        lastRenderState = renderState

        BeginDrawing()
        ClearBackground(.black)
        draw(appState: _appState, time: time, isNightTime: isNightTime)
        EndDrawing()
    }

    /// `EndDrawing` swaps the buffers, polls the input and keeps the frame rate.
    /// Nothing is drawn, so only the input and the frame rate have to be kept,
    /// the front buffer is left untouched with the last rendered frame on it.
    static private func skipFrame(frameStartTime: Double) {
        PollInputEvents()

        let targetFrameTime = 1.0 / Double(UI_FPS)
        let frameTime = GetTime() - frameStartTime

        if frameTime < targetFrameTime {
            WaitTime(targetFrameTime - frameTime)
        }
    }

    /// Events order only changes when the minute changes or the events are laid out again
    static private func updateEventsOrder(payload: CalendarPayload, time: CalendarUIUtils.TimeInfo) {
        guard eventsOrderMinutes != time.totalMinutes || eventsOrderRevision != payload.layoutRevision else {
            return
        }

        eventsOrderMinutes = time.totalMinutes
        eventsOrderRevision = payload.layoutRevision
        eventsOrder = CalendarUIUtils.getEventsOrder(events: payload.positionedEvents, time: time)
    }

    static private func resetEventsOrder() {
        eventsOrder = (nil, nil, nil, nil)
        eventsOrderMinutes = -1
        eventsOrderRevision = nil
    }

    static private func draw(
        appState _appState: AppStateData,
        time: CalendarUIUtils.TimeInfo,
        isNightTime: Bool,
    ) {
        if isNightTime {
            CalendarTimeComponent.draw(time: time, appState: _appState)
            return
        }

        switch _appState.calendar {
            case .loading:
                CalendarLoadingComponent.draw()
                CalendarTimeComponent.draw(time: time, appState: _appState)

            case .loaded(let payload):
                CalendarBackground.draw(time: time, appState: _appState)
                CalendarActiveEventAlarmEffect.draw(
                    time: time,
                    appState: _appState,
                    eventsOrder: eventsOrder,
                    eventsNavigation: eventsNavigation,
                )
                // draw time line behind the active event
                if eventsOrder.activeEvent != nil {
                    CalendarTimeComponent.draw(
                        time: time,
                        appState: _appState,
                        eventsOrder: eventsOrder,
                        eventsNavigation: eventsNavigation,
                    )
                }

                // events cards are created only when the list of events changes,
                // after that only their dynamic properties are updated
                if eventsCardsRevision != payload.layoutRevision {
                    eventsCardsRevision = payload.layoutRevision
                    eventsCards = payload.positionedEvents.enumerated().map { index, event in
                        CalendarEventCardComponent(
                            positionedEvent: event,
                            index: index,
                            startOfDay: time.startOfDay,
                        )
                    }
                }

                let eventsCardsContext = CalendarEventCardComponent.Context(
                    time: time,
                    appState: _appState,
                    eventsOrder: eventsOrder,
                    eventsNavigation: eventsNavigation,
                    selectedEventIndex: selectedEventIndex,
                )
                let highlightedEventIndex = eventsNavigation?.eventIndex
                var outsideLeftEdgeIndex: Int = 0
                var outsideRightEdgeIndex: Int = 0

                for index in eventsCards.indices {
                    eventsCards[index]?.update(
                        context: eventsCardsContext,
                        leftEdgeCounter: &outsideLeftEdgeIndex,
                        rightEdgeCounter: &outsideRightEdgeIndex,
                    )
                    // the highlighted event is drawn on top of the time line
                    if index != highlightedEventIndex {
                        eventsCards[index]?.draw()
                    }
                }

                // draw time above event border if time is outside active event boundaries
                if eventsOrder.activeEvent == nil {
                    CalendarTimeComponent.draw(
                        time: time,
                        appState: _appState,
                        eventsOrder: eventsOrder,
                        eventsNavigation: eventsNavigation,
                    )
                }

                // selected or highlighted event
                if let highlightedEventIndex, eventsCards.indices.contains(highlightedEventIndex) {
                    eventsCards[highlightedEventIndex]?.draw()
                }

            case .failed(let error):
                CalendarErrorComponent.draw(
                    error: error,
                    time: time,
                    appState: _appState
                )
                CalendarTimeComponent.draw(time: time, appState: _appState)
        }

        // let elapsedTime = (GetTime() - animationStartTime) / animationDuration
        // let animationProgress = Animation.animateWith(value: Float(elapsedTime), .easeInCubic) * 100
        // let cubeSize: Float = 20.0;
        // var x: Float = 0
        // x = (SCREEN_WIDTH - cubeSize) / 100 * animationProgress
        // if animationDirection == -1 {
        //     x = SCREEN_WIDTH - cubeSize - x
        // }
        // DrawRectangleV(Vector2(x: x, y: 0), Vector2(x: cubeSize, y: 20), .red)

        // if elapsedTime >= 1.0 {
        //     animationStartTime = GetTime()
        //     animationDirection = animationDirection * -1
        // }
    }

    static private func handleKeyboardShortcuts(
        appState: AppState,
        hiddenEventsStore: HiddenEventsStore,
        payload: CalendarPayload,
        time: CalendarUIUtils.TimeInfo,
    ) {
        let events = payload.positionedEvents

        if KEY_ESCAPE.isPressed {
            if eventsNavigation != nil {
                eventsNavigation = nil
                selectedEventIndex = nil
            } else if let flashingEvent = eventsOrder.activeEvent ?? eventsOrder.approachingEvent {
                appState.update { state in
                    state.calendar.updatePayload { payload in
                        payload.confirmedApproachingEventId = flashingEvent.event.id
                    }
                }
            }
        }
        if KEY_B.isPressed {
            appState.update { state in
                state.backgroundVisible = !state.backgroundVisible
            }
        }
        if KEY_LEFT.isPressed || KEY_RIGHT.isPressed {
            eventsNavigation = CalendarUIUtils.getEventsNavigation(
                time: time,
                events: events,
                eventsOrder: eventsOrder,
                eventsNavigation: eventsNavigation,
                direction: KEY_LEFT.isPressed ? .left : .right,
            )
            if eventsNavigation?.eventIndex != selectedEventIndex {
                selectedEventIndex = nil
            }
        }
        // the remaining shortcuts act on the event the navigation highlights
        guard let eventsNavigation,
            events.indices.contains(eventsNavigation.eventIndex)
        else {
            return
        }

        let highlightedEvent = events[eventsNavigation.eventIndex]

        if KEY_ENTER.isPressed {
            // a hidden event is brought back instead of being opened
            if highlightedEvent.isHidden {
                setEventHidden(
                    false,
                    eventId: highlightedEvent.event.id,
                    appState: appState,
                    hiddenEventsStore: hiddenEventsStore,
                    time: time,
                )
            } else {
                selectedEventIndex = eventsNavigation.eventIndex
            }
        }

        if !highlightedEvent.isHidden && (KEY_DELETE.isPressed || KEY_BACKSPACE.isPressed) {
            setEventHidden(
                true,
                eventId: highlightedEvent.event.id,
                appState: appState,
                hiddenEventsStore: hiddenEventsStore,
                time: time,
            )
            // the card the selection was opened for is gone
            selectedEventIndex = nil
        }
    }

    /// Hides or shows an event for the rest of the day. The store owns the ids,
    /// they are written to the disk and mirrored into the app state, so a reload
    /// of the events can never bring a hidden one back.
    static private func setEventHidden(
        _ isHidden: Bool,
        eventId: String,
        appState: AppState,
        hiddenEventsStore: HiddenEventsStore,
        time: CalendarUIUtils.TimeInfo,
    ) {
        let hiddenEventIds = hiddenEventsStore.setHidden(isHidden, eventId: eventId, on: time.startOfDay)

        appState.update { state in
            state.calendar.updatePayload { payload in
                payload.hiddenEventIds = hiddenEventIds
            }
        }
    }
}