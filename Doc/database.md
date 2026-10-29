Table Users 
{
    id : uuid
    username : varchar(50)
    password_hash : varchar(255)
    role : varchar(50) -- 'ADMIN' or 'USER'
    is_active : char(1) -- 'O' or 'N'
    can_see_all_caisses : char(1) -- 'O' or 'N'
    can_create : char(1) -- 'O' or 'N' (Permission ajout/création)
    can_update : char(1) -- 'O' or 'N' (Permission modification)
    can_delete : char(1) -- 'O' or 'N' (Permission suppression)
    can_manage_comptes : char(1) -- 'O' or 'N' (Gestion comptes vs Consultation seule)
    can_create_mov : char(1) -- 'O' or 'N'
    can_update_mov : char(1) -- 'O' or 'N'
    can_delete_mov : char(1) -- 'O' or 'N'
    can_view_journal_suppr : char(1) -- 'O' or 'N' (Accès au journal des suppressions)
    can_view_old_solde : char(1) -- 'O' or 'N' (Peut voir l'ancien solde / solde initial)
    created_at : timestamp
    updated_at : timestamp
}

Table User_Caisse_Access
{
    id : varchar(36) pk
    user_id : varchar(36) fk users.id
    compte_id : varchar(36) fk comptes.id
    created_at : timestamp
}

Table Comptes  
{
    id : varchar(36) -- uuid
    code:varchar(50)
    compte_fr : varchar(100)
    bg : int,
    bd : int,
    niveau : int 
    is_active : char(1) -- 'O' or 'N'
    created_at : timestamp
    updated_at : timestamp
    userid uuid not null 
}
Note : in compte table create index on code and compte_fr and create compte default with database 
1 - TOUS LES COMPTES is parent compte of tout le compte 
this tree of compte 
     TOUS LES COMPTES
         |_charges
             |_salaire
             |_loyer
             |_eau et electricite
             |_transport
             |_telephone
             |_internet
             |_fournitures de bureau
             |_entretien
             |_autres charges
         |_achat et vent
     caisse et banque
         |_caisse
             |_caisse principale
             |_caisse mobile
         |_banque
            |_banque principal
like this and this a compte can't be deletable or 
if it has mouvementsTrisor they can't be deletable 
and when create and sub_compte the compte has sub not show in mouvementTrisor 

Table MovementsTrisor  
{
    id : varchar(36) -- uuid
    date_mov : timestamp
    compte_source_id : varchar(36) fk comptes.id "is id of compte sortante"
    compte_dest_id : varchar(36) fk comptes.id "is id of compte entrante"
    montant : decimal(18,2)
    designation : varchar(500)
    user_id : uuid not null fk users.id
    created_at : timestamp
    updated_at : timestamp
}
compte_source_id and compte_dest_id means if i do mov in caisse in exemple i put 10000 salaire of ahmed in caisse principale
so ahmed is compte_dest_id and caisse principale is compte_source_id 

Table TypeTiers
{
    id : int
    type : varchar(50)
}

Table Tiers 
{
    id : varchar(36) -- uuid
    id_type_client : int
    nom : varchar(50)
    RC: varchar(50)
    NIF: varchar(50)
    AI: varchar(50)
    NIS: varchar(50)
    adresse : varchar(50)
    telephone : varchar(50)
    email : varchar(50)
    user_id : uuid not null fk users.id
    created_at : timestamp
    updated_at : timestamp
}

Table Facture_achat 
{
    id : varchar(36) -- uuid
    tiers_id : varchar(36) fk tiers.id
    num_facture : varchar(50)
    date_facture : timestamp
    montant : decimal(18,2)
    designation : varchar(500)
    user_id : uuid not null fk users.id
    created_at : timestamp
    updated_at : timestamp
}

Table Facture_vente 
{
    id : varchar(36) -- uuid
    tiers_id : varchar(36) fk tiers.id
    num_facture : varchar(50)
    date_facture : timestamp
    montant : decimal(18,2)
    designation : varchar(500)
    user_id : uuid not null fk users.id
    created_at : timestamp
    updated_at : timestamp
}

Table User_access
{
    id : varchar(36) -- uuid
    user_id : uuid fk users.id
    table : varchar(50)
    is_active : char(1) -- 'O' or 'N'
    created_at : timestamp
    updated_at : timestamp
}
in access user i want do acess for every thing read and write and delet and update
1- users 
2- compte
3- mouvementTrisor
4- Tiers
5- Facture_achat
6- Facture_vente
7- User_access 
