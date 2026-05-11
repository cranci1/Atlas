//
//  Models.swift
//  Atlas
//
//  Created by Francesco on 11/05/26.
//

import Foundation

public protocol PKIdentifiable {
    var pk: String { get }
}

public enum APIOperation<T: Codable>: Codable {
    case delete(String)
    case insert(T)
    
    private enum CodingKeys: String, CodingKey { case operazione, pk }
    
    public init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        let op = try c.decodeIfPresent(String.self, forKey: .operazione)
        if op == "D" {
            self = .delete(try c.decode(String.self, forKey: .pk))
        } else {
            self = .insert(try T(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .delete(let pk):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("D", forKey: .operazione)
            try c.encode(pk,  forKey: .pk)
        case .insert(let v): try v.encode(to: encoder)
        }
    }
}

public enum APIOperationCustomPK<T: Codable>: Codable {
    case delete(String)
    case insert(T)
    
    private enum CodingKeys: String, CodingKey { case operazione, pk }
    
    public init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        let op = try c.decodeIfPresent(String.self, forKey: .operazione)
        if op == "D" {
            self = .delete(try c.decode(String.self, forKey: .pk))
        } else {
            self = .insert(try T(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .delete(let pk):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("D", forKey: .operazione)
            try c.encode(pk,  forKey: .pk)
        case .insert(let v): try v.encode(to: encoder)
        }
    }
}

public struct Token: Codable {
    public let access_token:  String
    public let expires_in:    Int
    public let id_token:      String
    public let refresh_token: String
    public let scope:         String
    public let token_type:    String
    public var expireDate:    Date
}

public struct LoginData: Codable {
    public let codMin:              String
    public let opzioni:             [Opzione]
    public let isPrimoAccesso:      Bool
    public let profiloDisabilitato: Bool
    public let isResetPassword:     Bool
    public let isSpid:              Bool
    public let token:               String
    public let username:            String
}

public struct Opzione: Codable {
    public let valore: Bool
    public let chiave: String
}

public struct LoginResponse: Codable {
    public let success: Bool
    public let msg:     String?
    public let data:    [LoginData]
    public let total:   Int
}

public struct ProfiloResponse: Codable {
    public let success: Bool
    public let msg:     String?
    public let data:    Profilo
}

public struct Profilo: Codable {
    public let resetPassword:       Bool
    public let ultimoCambioPwd:     String?
    public let anno:                AnnoScolastico
    public let genitore:            GenitoreInfo
    public let profiloDisabilitato: Bool
    public let isSpid:              Bool
    public let alunno:              AlunnoInfo
    public let scheda:              Scheda
    public let primoAccesso:        Bool
    public let profiloStorico:      Bool
}

public struct AnnoScolastico: Codable {
    public let dataInizio: String
    public let anno:       String
    public let dataFine:   String
}

public struct GenitoreInfo: Codable {
    public let desEMail:    String
    public let nominativo:  String
    public let pk:          String
    
    enum CodingKeys: String, CodingKey {
        case desEMail
        case nominativo
        case pk
    }
    
    public init(desEMail: String = "", nominativo: String = "", pk: String = "") {
        self.desEMail = desEMail
        self.nominativo = nominativo
        self.pk = pk
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.desEMail = try container.decodeIfPresent(String.self, forKey: .desEMail) ?? ""
            self.nominativo = try container.decodeIfPresent(String.self, forKey: .nominativo) ?? ""
            self.pk = try container.decodeIfPresent(String.self, forKey: .pk) ?? ""
            return
        }
        
        let single = try decoder.singleValueContainer()
        let value = try single.decode(String.self)
        self.desEMail = ""
        self.nominativo = value
        self.pk = ""
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(desEMail, forKey: .desEMail)
        try container.encode(nominativo, forKey: .nominativo)
        try container.encode(pk, forKey: .pk)
    }
}

public struct AlunnoInfo: Codable {
    public let isUltimaClasse: Bool
    public let nominativo:     String
    public let cognome:        String
    public let nome:           String
    public let pk:             String
    public let maggiorenne:    Bool
    public let desEmail:       String?
}

public struct Scheda: Codable {
    public let classe: ClasseInfo
    public let corso:  CorsoInfo
    public let sede:   SedeInfo
    public let scuola: ScuolaInfo
    public let pk:     String
}

public struct ClasseInfo: Codable {
    public let pk:              String
    public let desDenominazione: String
    public let desSezione:      String
}

public struct CorsoInfo: Codable {
    public let descrizione: String
    public let pk:          String
}

public struct SedeInfo: Codable {
    public let descrizione: String
    public let pk:          String
}

public struct ScuolaInfo: Codable {
    public let desOrdine:   String
    public let descrizione: String
    public let pk:          String
}

public struct DashboardResponse: Codable {
    public let success: Bool
    public let msg:     String?
    public let data:    DashboardData
}

public struct DashboardData: Codable {
    public let dati: [DashboardRaw]
}

public struct DashboardRaw: Codable {
    public let fuoriClasse: [APIOperation<FuoriClasse>]?
    public let msg: String?
    public let opzioni: [Opzione]?
    public let mediaGenerale: Double?
    public let listaMaterie: [MateriaLight]?
    public let rimuoviDatiLocali: Bool?
    public let listaPeriodi: [Periodo]?
    public let promemoria: [APIOperation<Promemoria>]?
    public let bacheca: [APIOperation<BachecaItem>]?
    public let voti: [APIOperation<Voto>]?
    public let bachecaAlunno: [APIOperation<BachecaAlunnoItem>]?
    public let registro: [APIOperation<RegistroEntry>]?
    public let appello: [APIOperation<AppelloEntry>]?
    public let prenotazioniAlunni: [APIOperationCustomPK<PrenotazioneAlunno>]?
    public let listaDocentiClasse: [DocenteClasse]?
    public let mediaMaterie: [String: MediaMateria]?
    public let mediaPerPeriodo: [String: MediaPeriodo]?
    public let ricaricaDati: Bool?
    public let profiloDisabilitato: Bool?
    public let classiExtra: Bool?
    public let pk: String?
}

public struct DashboardDati: Codable {
    public let fuoriClasse:         [FuoriClasse]
    public let msg:                 String
    public let opzioni:             [Opzione]
    public let mediaGenerale:       Double
    public let listaMaterie:        [MateriaLight]
    public let rimuoviDatiLocali:   Bool
    public let listaPeriodi:        [Periodo]?
    public let promemoria:          [Promemoria]
    public let bacheca:             [BachecaItem]
    public let voti:                [Voto]
    public let bachecaAlunno:       [BachecaAlunnoItem]
    public let registro:            [RegistroEntry]
    public let appello:             [AppelloEntry]
    public let prenotazioniAlunni:  [PrenotazioneAlunno]
    public let listaDocentiClasse:  [DocenteClasse]
    public let mediaMaterie:        [String: MediaMateria]
    public let mediaPerPeriodo:     [String: MediaPeriodo]?
    public let ricaricaDati:        Bool
    public let profiloDisabilitato: Bool
    public let classiExtra:         Bool
    public let pk:                  String
    public let dataAggiornamento:   Date
}

public struct FuoriClasse: Codable, PKIdentifiable {
    public let pk:              String
    public let datEvento:       String
    public let descrizione:     String
    public let data:            String
    public let docente:         String
    public let nota:            String
    public let frequenzaOnLine: Bool
}

public struct MateriaLight: Codable {
    public let abbreviazione: String
    public let scrut:         Bool
    public let codTipo:       String
    public let faMedia:       Bool
    public let materia:       String
    public let pk:            String
}

public struct Periodo: Codable {
    public let pkPeriodo:        String
    public let dataInizio:       String
    public let descrizione:      String
    public let votoUnico:        Bool
    public let mediaScrutinio:   Double
    public let isMediaScrutinio: Bool
    public let dataFine:         String
    public let codPeriodo:       String
    public let isScrutinioFinale: Bool
}

public struct Promemoria: Codable, PKIdentifiable {
    public let pk:                 String
    public let datEvento:          String
    public let desAnnotazioni:     String
    public let pkDocente:          String
    public let flgVisibileFamiglia: String
    public let datGiorno:          String
    public let docente:            String
    public let oraInizio:          String
    public let oraFine:            String
}

public struct BachecaItem: Codable, PKIdentifiable {
    public let pk:                       String
    public let datEvento:                String
    public let messaggio:                String
    public let data:                     String
    public let pvRichiesta:              Bool
    public let categoria:                String
    public let dataConfermaPresaVisione: String
    public let url:                      String?
    public let autore:                   String
    public let dataScadenza:             String?
    public let adRichiesta:              Bool
    public let isPresaVisione:           Bool
    public let dataConfermaAdesione:     String
    public let listaAllegati:            [Allegato]
    public let dataScadAdesione:         String?
    public let isPresaAdesioneConfermata: Bool
}

public struct Allegato: Codable {
    public let nomeFile:         String
    public let path:             String
    public let descrizioneFile:  String?
    public let pk:               String
    public let url:              String
}

public struct Voto: Codable, Identifiable, PKIdentifiable {
    public var id: String { pk }
    public let pk:              String
    public let datEvento:       String
    public let pkPeriodo:       String
    public let codCodice:       String
    public let valore:          Double
    public let codVotoPratico:  String
    public let docente:         String
    public let pkMateria:       String
    public let tipoValutazione: String?
    public let prgVoto:         Int
    public let descrizioneProva: String
    public let faMenoMedia:     String
    public let pkDocente:       String
    public let descrizioneVoto: String
    public let codTipo:         String
    public let datGiorno:       String
    public let mese:            Int
    public let numMedia:        Double
    public let desMateria:      String
    public let desCommento:     String
}

public struct BachecaAlunnoItem: Codable, PKIdentifiable {
    public let pk:                  String
    public let nomeFile:            String
    public let datEvento:           String
    public let messaggio:           String
    public let data:                String
    public let flgDownloadGenitore: String
    public let isPresaVisione:      Bool
}

public struct RegistroEntry: Codable, Identifiable, PKIdentifiable {
    public var id: String { pk }
    public let pk:        String
    public let datEvento: String
    public let isFirmato: Bool
    public let desUrl:    String?
    public let pkDocente: String
    public let compiti:   [Compito]
    public let datGiorno: String
    public let docente:   String
    public let materia:   String
    public let pkMateria: String
    public let attivita:  String?
    public let ora:       Int
}

public struct Compito: Codable {
    public let compito:       String
    public let dataConsegna:  String
}

public struct AppelloEntry: Codable, Identifiable, PKIdentifiable {
    public var id: String { pk }
    public let pk:                     String
    public let datEvento:              String
    public let descrizione:            String
    public let daGiustificare:         Bool
    public let giustificata:           String
    public let data:                   String
    public let codEvento:              String
    public let docente:                String
    public let commentoGiustificazione: String
    public let dataGiustificazione:    String
    public let nota:                   String
}

public struct PrenotazioneAlunno: Codable {
    public let datEvento:    String
    public let prenotazione: Prenotazione
    public let disponibilita: DisponibilitaPrenotazione
    public let docente:      DocenteInfo
}

public struct Prenotazione: Codable {
    public let pk:                  String
    public let prgScuola:           Int
    public let datPrenotazione:     String
    public let numPrenotazione:     Int?
    public let prgAlunno:           Int
    public let genitore:            String
    public let numMax:              Int
    public let orarioPrenotazione:  String
    public let prgGenitore:         Int
    public let flgAnnullato:        String?
    public let flgAnnullatoDa:      String?
    public let desTelefonoGenitore: String
    public let flgTipo:             String?
    public let datAnnullamento:     String?
    public let desUrl:              String?
    public let genitorePK:          String
    public let desEMailGenitore:    String
    public let numPrenotazioni:     Int?
}

public struct DisponibilitaPrenotazione: Codable {
    public let pk:                  String
    public let ora_Fine:            String
    public let desNota:             String
    public let datDisponibilita:    String
    public let desUrl:              String
    public let numMax:              Int
    public let ora_Inizio:          String
    public let flgAttivo:           String
    public let desLuogoRicevimento: String
}

public struct DocenteClasse: Codable {
    public let desCognome: String
    public let materie:    [String]
    public let desNome:    String
    public let pk:         String
    public let desEmail:   String
}

public struct DocenteInfo: Codable {
    public let desCognome: String
    public let desNome:    String
    public let pk:         String
    public let desEmail:   String
}

public struct MediaMateria: Codable {
    public let sommaValutazioniOrale:   Double
    public let numValutazioniOrale:     Int
    public let mediaMateria:            Double
    public let mediaScritta:            Double
    public let sumValori:               Double
    public let numValori:               Int
    public let numVoti:                 Int
    public let numValutazioniScritto:   Int
    public let sommaValutazioniScritto: Double
    public let mediaOrale:              Double
}

public struct MediaPeriodo: Codable {
    public let mediaGenerale:  Double
    public let listaMaterie:   [String: MediaMateria]
    public let mediaMese:      [String: Double]
}

public struct OrarioGiornalieroResponse: Codable {
    public let success: Bool
    public let msg:     String?
    public let data:    OrarioData
}

public struct OrarioData: Codable {
    public let dati: [String: [OraLezione]]
}

public struct OraLezione: Codable, Identifiable {
    public var id: String { pk ?? "\(numOra)-\(docente)" }
    public let numOra:          Int
    public let mostra:          Bool
    public let desCognome:      String
    public let desNome:         String
    public let docente:         String
    public let materia:         String
    public let pk:              String?
    public let desDenominazione: String
    public let desEmail:        String
    public let desSezione:      String
    public let ora:             String?
}

public struct DettagliProfiloResponse: Codable {
    public let success: Bool
    public let msg:     String?
    public let data:    DettagliProfilo
}

public struct DettagliProfilo: Codable {
    public let utente:   UtenteInfo
    public let genitore: DettagliGenitore
    public let alunno:   DettagliAlunno
}

public struct UtenteInfo: Codable {
    public let flgUtente: String
}

public struct DettagliGenitore: Codable {
    public let flgSesso:      String
    public let desCognome:    String
    public let desEMail:      String
    public let desCellulare:  String?
    public let desTelefono:   String
    public let desNome:       String
    public let datNascita:    String
}

public struct DettagliAlunno: Codable {
    public let cognome:              String
    public let desCellulare:         String?
    public let desCf:                String
    public let datNascita:           String
    public let desCap:               String
    public let desComuneResidenza:   String
    public let nome:                 String
    public let desComuneNascita:     String
    public let desCapResidenza:      String
    public let cittadinanza:         String
    public let desIndirizzoRecapito: String
    public let desEMail:             String?
    public let nominativo:           String
    public let desVia:               String
    public let desTelefono:          String
    public let sesso:                String
    public let desComuneRecapito:    String
}

public struct TasseResponse: Codable {
    public let success:          Bool
    public let msg:              String?
    public let data:             [Tassa]
    public let isPagOnlineAttivo: Bool
}

public struct Tassa: Codable, Identifiable {
    public var id: String { iuv ?? descrizione }
    public let importoPrevisto:         String
    public let dataPagamento:           String?
    public let listaSingoliPagamenti:   [SingoloPagamento]?
    public let dataCreazione:           String?
    public let scadenza:                String
    public let rptPresent:              Bool
    public let rata:                    String
    public let iuv:                     String?
    public let importoTassa:            String
    public let stato:                   String
    public let descrizione:             String
    public let debitore:                String
    public let importoPagato:           String?
    public let pagabileOltreScadenza:   Bool
    public let rtPresent:               Bool
    public let isPagoOnLine:            Bool
    public let status:                  String
}

public struct SingoloPagamento: Codable {
    public let importoTassa:    String
    public let descrizione:     String
    public let importoPrevisto: String
}

public struct RicevimentiResponse: Codable {
    public let success: Bool
    public let msg:     String?
    public let data:    RicevimentiData
}

public struct RicevimentiData: Codable {
    public let disponibilita:   [String: [DisponibilitaRicevimento]]
    public let genitoreOAlunno: [GenitoreAlunnoInfo]
    public let tipoAccesso:     String
    public let prenotazioni:    [PrenotazioneRicevimento]
}

public struct DisponibilitaRicevimento: Codable {
    public let pk:                       String
    public let desNota:                  String
    public let numMax:                   Int
    public let docente:                  DocenteRecapito
    public let numPrenotazioniAnnullate: Int?
    public let flgAttivo:                String
    public let oraFine:                  String
    public let indisponibilita:          String?
    public let datInizioPrenotazione:    String
    public let desUrl:                   String
    public let unaTantum:                String
    public let oraInizioPrenotazione:    String
    public let datScadenza:              String
    public let desLuogoRicevimento:      String
    public let oraInizio:                String
    public let flgMostraEmail:           String
    public let desEMailDocente:          String
    public let numPrenotazioni:          Int
}

public struct DocenteRecapito: Codable {
    public let desCognome: String
    public let desNome:    String
    public let pk:         String
    public let desEmail:   String?
}

public struct GenitoreAlunnoInfo: Codable {
    public let desEMail:   String
    public let nominativo: String
    public let pk:         String
    public let telefono:   String
}

public struct PrenotazioneRicevimento: Codable {
    public let operazione:   String
    public let datEvento:    String
    public let prenotazione: Prenotazione
    public let disponibilita: DisponibilitaPrenotazione
    public let docente:      DocenteInfo
}

public struct VotiScrutinioResponse: Codable {
    public let success: Bool
    public let msg:     String?
    public let data:    VotiScrutinioData
}

public struct VotiScrutinioData: Codable {
    public let votiScrutinio: [VotoScrutinio]
}

public struct VotoScrutinio: Codable {
    public let periodi: [PeriodoScrutinio]
    public let pk:      String
}

public struct PeriodoScrutinio: Codable {
    public let desDescrizione:  String
    public let materie:         [String]
    public let suddivisione:    String
    public let votiGiudizi:     Bool
    public let scrutinioFinale: Bool
}

public struct CurriculumResponse: Codable {
    public let success: Bool
    public let msg:     String?
    public let data:    CurriculumData
}

public struct CurriculumData: Codable {
    public let curriculum: [CurriculumEntry]
}

public struct CurriculumEntry: Codable, Identifiable {
    public var id: String { pkScheda }
    public let pkScheda:        String
    public let classe:          String
    public let anno:            Int
    public let credito:         Int
    public let mostraInfo:      Bool
    public let mostraCredito:   Bool
    public let isSuperiore:     Bool
    public let isInterruzioneFR: Bool
    public let media:           Double?
    public let CVAbilitato:     Bool
    public let ordineScuola:    String
}

public struct WhatResponse: Codable {
    public let success: Bool
    public let msg:     String?
    public let data:    WhatData
}

public struct WhatData: Codable {
    public let dati: [WhatDati]
}

public struct WhatDati: Codable {
    public let forceLogin:      Bool
    public let isModificato:    Bool
    public let pk:              String
    public let alunno:          AlunnoInfo
    public let mostraPallino:   Bool
    public let scheda:          SchedaWhat
    public let differenzaSchede: Bool
    public let profiloStorico:  Bool
}

public struct SchedaWhat: Codable {
    public let aggiornaSchedaPK: Bool
    public let classe:           ClasseInfo
    public let dataInizio:       String
    public let anno:             Int
    public let corso:            CorsoInfo
    public let sede:             SedeInfo
    public let scuola:           ScuolaInfo
    public let dataFine:         String
    public let pk:               String
}

public struct GenericResponse: Codable {
    public let success: Bool
    public let msg:     String?
}

public struct DownloadAllegatoResponse: Codable {
    public let success: Bool
    public let msg:     String?
    public let url:     String?
}
