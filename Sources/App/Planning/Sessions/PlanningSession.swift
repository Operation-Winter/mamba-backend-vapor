//
//  PlanningSession.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import MambaNetworking

actor PlanningSession {
    nonisolated let id: String
    nonisolated let hostId: UUID
    private(set) var name: String
    private(set) var availableCards: [PlanningCard]
    private(set) var participants: [PlanningParticipant] {
        didSet { resetIdleTimer() }
    }
    private(set) var spectators: [PlanningSpectator] {
        didSet { resetIdleTimer() }
    }
    private(set) var ticket: PlanningTicket? {
        didSet { resetIdleTimer() }
    }
    private(set) var state: PlanningSessionState {
        didSet { resetIdleTimer() }
    }
    private(set) var previousTickets: [PlanningTicket] {
        didSet { resetIdleTimer() }
    }
    private(set) var autoCompleteVoting: Bool
    private(set) weak var delegate: PlanningSessionDelegate?
    private var timer: DispatchSourceTimer?
    private var timerTimeLeft: Int?
    private var idleTimer: DispatchSourceTimer
    private var idleTimerMinutesLeft = 60
    private var coffeeRequestCount: Set<UUID> = []
    private var coffeeVotes: [PlanningCoffeeVote] {
        didSet { resetIdleTimer() }
    }
    private var previousState: PlanningSessionState? {
        didSet { resetIdleTimer() }
    }
    let password: String?
    
    private var stateMessage: PlanningSessionStateMessage {
        PlanningSessionStateMessage(sessionCode: id,
                                    sessionName: name,
                                    // Passwords are accepted only during join and must never be
                                    // broadcast to every connected participant.
                                    password: nil,
                                    availableCards: availableCards,
                                    participants: participants,
                                    ticket: ticket,
                                    timeLeft: timerTimeLeft,
                                    spectatorCount: spectators.count,
                                    coffeeRequestCount: coffeeRequestCount.count,
                                    coffeeVotes: coffeeVotes,
                                    updated: Date())
    }
    
    init(id: String,
         hostId: UUID = UUID(),
         name: String,
         password: String?,
         availableCards: [PlanningCard],
         autoCompleteVoting: Bool,
         participants: [PlanningParticipant] = [],
         spectators: [PlanningSpectator] = [],
         ticket: PlanningTicket? = nil,
         state: PlanningSessionState = .none,
         delegate: PlanningSessionDelegate? = nil,
         previousTickets: [PlanningTicket] = [],
         coffeeVotes: [PlanningCoffeeVote] = []) async {
        self.id = id
        self.hostId = hostId
        self.name = name
        self.password = password
        self.autoCompleteVoting = autoCompleteVoting
        self.availableCards = availableCards.sorted { $0.sortOrder < $1.sortOrder }
        self.participants = participants
        self.spectators = spectators
        self.ticket = ticket
        self.state = state
        self.delegate = delegate
        self.previousTickets = previousTickets
        self.coffeeVotes = coffeeVotes
        idleTimer = DispatchSource.makeTimerSource()
        configureIdleTimer()
    }
    
    // MARK: - Session idle timer
    
    private func configureIdleTimer() {
        idleTimer.schedule(deadline: .now() + .seconds(60), repeating: .seconds(60))
        idleTimer.setEventHandler() { [weak self] in
            guard let self = self else { return }
            Task {
                await self.configureIdleTimeLeft(self.idleTimerMinutesLeft - 1)
                
                if await self.idleTimerMinutesLeft <= 0 {
                    await self.idleTimer.cancel()
                await self.delegate?.sessionHasTimedOut(sessionId: self.id)
                }
            }
        }
    
        idleTimer.activate()
    }
    
    private func configureIdleTimeLeft(_ timeLeft: Int) {
        idleTimerMinutesLeft = timeLeft
    }
    
    private func resetIdleTimer() {
        idleTimerMinutesLeft = 60
    }
    
    // MARK: - Send state to
    
    func sendState(to uuid: UUID) async {
        await delegate?.send(stateMessage: stateMessage, state: state, clientUuid: uuid)
    }
    
    func sendStateToAll() async {
        await delegate?.send(stateMessage: stateMessage, state: state, sessionId: id)
    }
    
    // MARK: - Add, update or remove clients
    
    func add(participant: PlanningParticipant) {
        guard !participants.contains(where: { $0.participantId == participant.participantId }) else { return }
        participants.append(participant)
    }
    
    func add(spectator: PlanningSpectator) {
        guard !spectators.contains(where: { $0.spectatorId == spectator.spectatorId }) else { return }
        spectators.append(spectator)
    }
    
    func updateParticipant(participantId: UUID, name: String) {
        participants
            .first { $0.participantId == participantId }?
            .name = name
        
        resetIdleTimer()
    }

    func updateParticipantConnection(participantId: UUID, connected: Bool) async {
        guard let participant = participants.first(where: { $0.participantId == participantId }),
              participant.connected != connected
        else { return }
        participant.connected = connected
        resetIdleTimer()
        await sendStateToAll()
    }
    
    func remove(participantId: UUID) {
        ticket?.removeVotes(participantId: participantId)
        participants.removeAll { $0.participantId == participantId }
    }
    
    func remove(spectatorId: UUID) {
        spectators.removeAll { $0.spectatorId == spectatorId }
    }
    
    // MARK: - Add or update ticket
    
    func add(ticket: PlanningTicket, uuid: UUID) async {
        guard state == .none || state == .votingFinished else {
            await delegate?.sendInvalidCommand(error: .invalidState, type: .host, clientUuid: uuid)
            return
        }
        if state == .votingFinished,
           let previousTicket = self.ticket,
           !previousTicket.ticketVotes.isEmpty {
            previousTickets.append(previousTicket)
        }
        self.ticket = ticket
        state = .voting
    }
    
    func updateTicket(title: String, description: String, selectedTags: Set<String>, uuid: UUID) async {
        guard (state == .voting || state == .votingFinished), ticket != nil else {
            await delegate?.sendInvalidCommand(error: .invalidState, type: .host, clientUuid: uuid)
            return
        }
        ticket?.title = title
        ticket?.description = description
        ticket?.selectedTags = selectedTags
        ticket?.removeVotesAll()
        
        resetIdleTimer()
    }
    
    // MARK: - Vote on ticket
    
    func add(vote card: PlanningCard?,
             tag: String?,
             uuid: UUID,
             commandType: PlanningSystemType = .join,
             commandUuid: UUID? = nil) async {
        guard state == .voting,
              let ticket = ticket,
              participants.contains(where: { $0.participantId == uuid })
        else {
            await delegate?.sendInvalidCommand(error: .invalidState,
                                               type: commandType,
                                               clientUuid: commandUuid ?? uuid)
            return
        }
        ticket.removeVotes(participantId: uuid)
        let vote = PlanningTicketVote(participantId: uuid, selectedCard: card, tag: tag)
        ticket.add(vote: vote)
        
        if autoCompleteVoting,
           ticket.ticketVotes.count == participants.count {
            state = .votingFinished
        }
        resetIdleTimer()
    }
    
    func update(vote card: PlanningCard?,
                tag: String?,
                uuid: UUID,
                commandType: PlanningSystemType = .join,
                commandUuid: UUID? = nil) async {
        guard state == .votingFinished,
              let ticket = ticket,
              participants.contains(where: { $0.participantId == uuid })
        else {
            await delegate?.sendInvalidCommand(error: .invalidState,
                                               type: commandType,
                                               clientUuid: commandUuid ?? uuid)
            return
        }
        ticket.removeVotes(participantId: uuid)
        let vote = PlanningTicketVote(participantId: uuid, selectedCard: card, tag: tag)
        ticket.add(vote: vote)

        resetIdleTimer()
    }
    
    func resetVotes(uuid: UUID) async {
        guard state == .votingFinished, ticket != nil else {
            await delegate?.sendInvalidCommand(error: .invalidState, type: .host, clientUuid: uuid)
            return
        }
        ticket?.removeVotesAll()
        state = .voting
    }

    func finishVotes(uuid: UUID) async {
        guard state == .voting, ticket != nil else {
            await delegate?.sendInvalidCommand(error: .invalidState, type: .host, clientUuid: uuid)
            return
        }
        for participant in participants {
            if ticket?.ticketVotes.contains(where: { $0.participantId == participant.participantId }) == false {
                await add(vote: nil, tag: nil, uuid: participant.participantId)
            }
        }
        state = .votingFinished
    }
    
    // MARK: - Coffee break voting
    
    
    func startCoffeeVoting(uuid: UUID) async {
        guard state != .coffeeBreakVoting, state != .coffeeBreakVotingFinished else {
            await delegate?.sendInvalidCommand(error: .invalidState, type: .host, clientUuid: uuid)
            return
        }
        previousState = state
        state = .coffeeBreakVoting
        coffeeRequestCount.removeAll()
    }
    
    func finishCoffeeVoting(uuid: UUID) async {
        guard state == .coffeeBreakVoting else {
            await delegate?.sendInvalidCommand(error: .invalidState, type: .host, clientUuid: uuid)
            return
        }
        state = .coffeeBreakVotingFinished
    }
    
    func endCoffeeVoting(uuid: UUID) async {
        guard state == .coffeeBreakVoting || state == .coffeeBreakVotingFinished else {
            await delegate?.sendInvalidCommand(error: .invalidState, type: .host, clientUuid: uuid)
            return
        }
        state = previousState ?? .none
        previousState = nil
        coffeeRequestCount.removeAll()
        coffeeVotes.removeAll()
    }
    
    func add(coffeBreakVote vote: Bool,
             uuid: UUID,
             commandType: PlanningSystemType = .join,
             commandUuid: UUID? = nil) async {
        guard state == .coffeeBreakVoting,
              uuid == hostId || participants.contains(where: { $0.participantId == uuid })
        else {
            await delegate?.sendInvalidCommand(error: .invalidUuid,
                                               type: commandType,
                                               clientUuid: commandUuid ?? uuid)
            return
        }
        coffeeVotes.removeAll { $0.participantId == uuid }
        let coffeeVote = PlanningCoffeeVote(participantId: uuid, vote: vote)
        coffeeVotes.append(coffeeVote)
        
        if coffeeVotes.count == participants.count + 1 {
            state = .coffeeBreakVotingFinished
        }
        resetIdleTimer()
    }
    
    func toggleCoffeeRequestVote(participantId: UUID,
                                 commandType: PlanningSystemType,
                                 commandUuid: UUID) async {
        guard participantId == hostId || participants.contains(where: { $0.participantId == participantId }) else {
            await delegate?.sendInvalidCommand(error: .invalidUuid,
                                               type: commandType,
                                               clientUuid: commandUuid)
            return
        }
        if coffeeRequestCount.contains(participantId) {
            coffeeRequestCount.remove(participantId)
        } else {
            coffeeRequestCount.insert(participantId)
        }
    }
    
    // MARK: - Timer

    func startTimer(with timeInterval: TimeInterval, uuid: UUID) async {
        guard timeInterval.isFinite,
              timeInterval >= 0,
              timeInterval <= 1800,
              timeInterval.rounded() == timeInterval,
              state == .voting,
              ticket != nil,
              timer == nil,
              timerTimeLeft == nil
        else {
            await delegate?.sendInvalidCommand(error: .invalidState, type: .host, clientUuid: uuid)
            return
        }
        timerTimeLeft = Int(timeInterval)
        timer = DispatchSource.makeTimerSource()
        let firstTick = timeInterval == 0 ? DispatchTime.now() : DispatchTime.now() + .seconds(1)
        timer?.schedule(deadline: firstTick, repeating: .seconds(1))
        
        timer?.setEventHandler() { [weak self] in
            guard let self = self else { return }
            Task {
                await self.handleTimerTick()
            }
        }
        await sendStateToAll()
        timer?.activate()
    }
    
    func configureTimerTimeLeft(_ timeLeft: Int?) {
        timerTimeLeft = timeLeft
    }

    private func clearTimer() {
        timer = nil
        timerTimeLeft = nil
    }

    private func handleTimerTick() async {
        guard let timerTimeLeft else { return }
        self.timerTimeLeft = max(0, timerTimeLeft - 1)

        if self.timerTimeLeft == 0 {
            timer?.cancel()
            clearTimer()
            await finishVotes(uuid: hostId)
            await sendStateToAll()
            resetIdleTimer()
        }
    }
    
    func cancelTimer(uuid: UUID) async {
        guard state == .voting,
              let timer = timer,
              timerTimeLeft != nil
        else {
            await delegate?.sendInvalidCommand(error: .noTimer, type: .host, clientUuid: uuid)
            return
        }
        
        timer.cancel()
        self.timer = nil
        timerTimeLeft = nil
        await sendStateToAll()
        resetIdleTimer()
    }
    
    // MARK: - Send previous tickets
    
    func sendPreviousTickets(uuid: UUID) async {
        if state == .votingFinished,
           let currentTicket = self.ticket,
           !currentTicket.ticketVotes.isEmpty,
           !previousTickets.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(currentTicket) }) {
            previousTickets.append(currentTicket)
        }
        
        let message = PlanningPreviousTicketsMessage(previousTickets: previousTickets)
        await delegate?.send(hostCommand: .previousTickets(message: message), clientUuid: uuid)
        resetIdleTimer()
    }
}
