//
//  PlanningSession.swift
//  
//
//  Created by Armand Kamffer on 2020/10/01.
//

import Foundation
import MambaNetworking
import OpenCombine

actor PlanningSession {
    nonisolated let id: CurrentValueSubject<String, Never>
    
    private(set) var _id: String {
        didSet { id.value = _id }
    }
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
        PlanningSessionStateMessage(sessionCode: _id,
                                    sessionName: name,
                                    password: password,
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
        self._id = id
        self.id = CurrentValueSubject(_id)
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
        idleTimer.schedule(deadline: .now(), repeating: .seconds(60))
        idleTimer.setEventHandler() { [weak self] in
            guard let self = self else { return }
            Task {
                await self.configureIdleTimeLeft(self.idleTimerMinutesLeft - 1)
                
                if await self.idleTimerMinutesLeft <= 0 {
                    await self.idleTimer.cancel()
                    await self.delegate?.sessionHasTimedOut(sessionId: self._id)
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
    
    func sendState(to uuid: UUID) {
        delegate?.send(stateMessage: stateMessage, state: state, clientUuid: uuid)
    }
    
    func sendStateToAll() {
        delegate?.send(stateMessage: stateMessage, state: state, sessionId: _id)
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
    
    func remove(participantId: UUID) {
        ticket?.removeVotes(participantId: participantId)
        participants.removeAll { $0.participantId == participantId }
    }
    
    func remove(spectatorId: UUID) {
        spectators.removeAll { $0.spectatorId == spectatorId }
    }
    
    // MARK: - Add or update ticket
    
    func add(ticket: PlanningTicket) {
        if state == .votingFinished,
           let previousTicket = self.ticket,
           !previousTicket.ticketVotes.isEmpty {
            previousTickets.append(previousTicket)
        }
        self.ticket = ticket
        state = .voting
    }
    
    func updateTicket(title: String, description: String, selectedTags: Set<String>) {
        ticket?.title = title
        ticket?.description = description
        ticket?.selectedTags = selectedTags
        ticket?.removeVotesAll()
        
        resetIdleTimer()
    }
    
    // MARK: - Vote on ticket
    
    func add(vote card: PlanningCard?, tag: String?, uuid: UUID) {
        guard state == .voting,
              let ticket = ticket,
              participants.contains(where: { $0.participantId == uuid })
        else {
            delegate?.sendInvalidCommand(error: .invalidParameters, type: .join, clientUuid: uuid)
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
    
    func resetVotes() {
        ticket?.removeVotesAll()
        state = .voting
    }
    
    func finishVotes() {
        participants.forEach { participant in
            if ticket?.ticketVotes.contains(where: { $0.participantId == participant.participantId }) == false {
                add(vote: nil, tag: nil, uuid: participant.participantId)
            }
        }
        state = .votingFinished
    }
    
    // MARK: - Coffee break voting
    
    
    func startCoffeeVoting() {
        previousState = state
        state = .coffeeBreakVoting
        coffeeRequestCount.removeAll()
    }
    
    func finishCoffeeVoting() {
        state = .coffeeBreakVotingFinished
    }
    
    func endCoffeeVoting() {
        state = previousState ?? .none
        previousState = nil
        coffeeRequestCount.removeAll()
        coffeeVotes.removeAll()
    }
    
    func add(coffeBreakVote vote: Bool, uuid: UUID) {
        guard state == .coffeeBreakVoting else {
            delegate?.sendInvalidCommand(error: .invalidParameters, type: .join, clientUuid: uuid)
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
    
    func toggleCoffeeRequestVote(participantId: UUID) {
        if coffeeRequestCount.contains(participantId) {
            coffeeRequestCount.remove(participantId)
        } else {
            coffeeRequestCount.insert(participantId)
        }
    }
    
    // MARK: - Timer

    func startTimer(with timeInterval: TimeInterval, uuid: UUID) {
        guard state == .voting,
              ticket != nil
        else {
            delegate?.sendInvalidCommand(error: .invalidState, type: .host, clientUuid: uuid)
            return
        }
        timerTimeLeft = Int(timeInterval)
        timer = DispatchSource.makeTimerSource()
        timer?.schedule(deadline: .now(), repeating: .seconds(1))
        
        timer?.setEventHandler() { [weak self] in
            guard let self = self else { return }
            Task {
                await self.configureTimerTimeLeft((self.timerTimeLeft ?? 1) - 1)
                
                if await self.timerTimeLeft ?? 0 <= 0 {
                    await self.timer?.cancel()
                    await self.configureTimerTimeLeft(nil)
                    await self.finishVotes()
                    await self.sendStateToAll()
                    await self.resetIdleTimer()
                }
            }
        }
    
        timer?.activate()
        sendStateToAll()
    }
    
    func configureTimerTimeLeft(_ timeLeft: Int?) {
        timerTimeLeft = timeLeft
    }
    
    func cancelTimer(uuid: UUID) {
        guard state == .voting,
              let timer = timer
        else {
            delegate?.sendInvalidCommand(error: .invalidParameters, type: .host, clientUuid: uuid)
            return
        }
        
        timer.cancel()
        timerTimeLeft = nil
        sendStateToAll()
        resetIdleTimer()
    }
    
    // MARK: - Send previous tickets
    
    func sendPreviousTickets(uuid: UUID) {
        if state == .votingFinished,
           let currentTicket = self.ticket,
           !currentTicket.ticketVotes.isEmpty,
           !previousTickets.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(currentTicket) }) {
            previousTickets.append(currentTicket)
        }
        
        let message = PlanningPreviousTicketsMessage(previousTickets: previousTickets)
        delegate?.send(hostCommand: .previousTickets(message: message), clientUuid: uuid)
        resetIdleTimer()
    }
}
