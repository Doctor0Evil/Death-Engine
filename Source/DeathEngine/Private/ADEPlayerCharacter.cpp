#include "ADEPlayerCharacter.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Components/InputComponent.h"

ADEPlayerCharacter::ADEPlayerCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    FirstPersonCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FirstPersonCamera"));
    FirstPersonCamera->SetupAttachment(GetMesh());
    FirstPersonCamera->bUsePawnControlRotation = true;

    // Initialize defaults
    Sanity = 1.0f;
    MaxStamina = 100.0f;
    Stamina = MaxStamina;
    WalkSpeed = 300.f;
    SprintSpeed = 600.f;
    CrouchSpeed = 150.f;
    bIsSprinting = false;

    GetCharacterMovement()->MaxWalkSpeed = WalkSpeed;
}

void ADEPlayerCharacter::BeginPlay()
{
    Super::BeginPlay();
    GetCharacterMovement()->MaxWalkSpeed = WalkSpeed;
}

void ADEPlayerCharacter::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);

    if (bIsSprinting)
    {
        DrainStamina(DeltaTime);
    }
    else
    {
        RegenerateStamina(DeltaTime);
    }
}

void ADEPlayerCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
    Super::SetupPlayerInputComponent(PlayerInputComponent);

    PlayerInputComponent->BindAxis("MoveForward", this, &ADEPlayerCharacter::MoveForward);
    PlayerInputComponent->BindAxis("MoveRight", this, &ADEPlayerCharacter::MoveRight);

    PlayerInputComponent->BindAction("Sprint", IE_Pressed, this, &ADEPlayerCharacter::StartSprint);
    PlayerInputComponent->BindAction("Sprint", IE_Released, this, &ADEPlayerCharacter::StopSprint);

    PlayerInputComponent->BindAction("Crouch", IE_Pressed, this, &ADEPlayerCharacter::StartCrouch);
    PlayerInputComponent->BindAction("Crouch", IE_Released, this, &ADEPlayerCharacter::StopCrouch);
}

void ADEPlayerCharacter::MoveForward(float Value)
{
    if (Controller && Value != 0.f)
    {
        const FRotator Rotation = Controller->GetControlRotation();
        const FRotator YawRot(0.f, Rotation.Yaw, 0.f);
        const FVector Direction = FRotationMatrix(YawRot).GetUnitAxis(EAxis::X);
        AddMovementInput(Direction, Value);
    }
}

void ADEPlayerCharacter::MoveRight(float Value)
{
    if (Controller && Value != 0.f)
    {
        const FRotator Rotation = Controller->GetControlRotation();
        const FRotator YawRot(0.f, Rotation.Yaw, 0.f);
        const FVector Direction = FRotationMatrix(YawRot).GetUnitAxis(EAxis::Y);
        AddMovementInput(Direction, Value);
    }
}

void ADEPlayerCharacter::StartSprint()
{
    if (Stamina > 0.f)
    {
        bIsSprinting = true;
        GetCharacterMovement()->MaxWalkSpeed = SprintSpeed;
    }
}

void ADEPlayerCharacter::StopSprint()
{
    bIsSprinting = false;
    GetCharacterMovement()->MaxWalkSpeed = WalkSpeed;
}

void ADEPlayerCharacter::StartCrouch()
{
    Crouch();
    GetCharacterMovement()->MaxWalkSpeed = CrouchSpeed;
}

void ADEPlayerCharacter::StopCrouch()
{
    UnCrouch();
    // Restore walk or sprint speed depending on sprint status
    GetCharacterMovement()->MaxWalkSpeed = bIsSprinting ? SprintSpeed : WalkSpeed;
}

void ADEPlayerCharacter::DrainStamina(float DeltaTime)
{
    if (Stamina > 0.f)
    {
        const float DrainRate = 20.f; // units per second
        Stamina -= DrainRate * DeltaTime;
        if (Stamina <= 0.f)
        {
            Stamina = 0.f;
            StopSprint();
        }
    }
}

void ADEPlayerCharacter::RegenerateStamina(float DeltaTime)
{
    if (Stamina < MaxStamina)
    {
        const float RegenRate = 10.f; // units per second
        Stamina += RegenRate * DeltaTime;
        if (Stamina > MaxStamina)
        {
            Stamina = MaxStamina;
        }
    }
}
