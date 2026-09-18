package com.example.taskmanager.repository;

import com.example.taskmanager.model.UserCova;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<UserCova, Long> {
    // Permet de retrouver un utilisateur grâce à son e-mail (pour le login)
    Optional<UserCova> findByEmail(String email);
    
    // Permet de vérifier si un e-mail est déjà utilisé (pour le register)
    Boolean existsByEmail(String email);
}