#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "Camera/CameraComponent.h"
#include "ADEPlayerCharacter.generated.h"

/**
 * Base player character class.
 * Blueprintable and designed for first-person input, stamina, sanity, sprint, crouch.
 */
UCLASS(Blueprintable)
class DEATHENGINE_API ADEPlayerCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ADEPlayerCharacter();

    /** First-person camera */
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Camera")
    UCameraComponent* FirstPersonCamera;

    /** Player sanity from 0 (insane) to 1 (normal) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Horror")
    float Sanity;

    /** Player stamina */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Stats")
    float Stamina;

    /** Maximum stamina */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Stats")
    float MaxStamina;

    /** Is player currently sprinting */
    UPROPERTY(BlueprintReadOnly, Category="Movement")
    bool bIsSprinting;

    /** Default walk speed */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Movement")
    float WalkSpeed;

    /** Sprint walk speed */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Movement")
    float SprintSpeed;

    /** Crouch walk speed */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Movement")
    float CrouchSpeed;

    /** Drain stamina while sprinting */
    UFUNCTION(BlueprintCallable, Category="Stats")
    void DrainStamina(float DeltaTime);

    /** Regenerate stamina when not sprinting */
    UFUNCTION(BlueprintCallable, Category="Stats")
    void RegenerateStamina(float DeltaTime);

protected:
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaTime) override;
    virtual void SetupPlayerInputComponent(class UInputComponent* PlayerInputComponent) override;

    void MoveForward(float Value);
    void MoveRight(float Value);
    
    UFUNCTION(BlueprintCallable, Category="Movement")
    void StartSprint();

    UFUNCTION(BlueprintCallable, Category="Movement")
    void StopSprint();

    UFUNCTION(BlueprintCallable, Category="Movement")
    void StartCrouch();

    UFUNCTION(BlueprintCallable, Category="Movement")
    void StopCrouch();
};
