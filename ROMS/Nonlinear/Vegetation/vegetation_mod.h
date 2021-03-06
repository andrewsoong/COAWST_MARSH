!
!svn $Id: vegetation_mod.h 429 2015-06-10 17:30:26Z arango $
!================================================== Hernan G. Arango ===
!  Copyright (c) 2002-2016 The ROMS/TOMS Group                         !
!    Licensed under a MIT/X style license                              !
!    See License_ROMS.txt                                              !
!================================================= John C. Warner =====!   
!================================================= Neil K. Ganju ======!   
!================================================= Alexis Beudin ======!   
!================================================= Tarandeep S. Kalra =!
!=======================================================================
!                                                                      !
!  Vegetation Model Kernel Variables:                                  !
!  =================================                                   !
!  NVEG          Number of vegetation types                            !
!  NVEGP         Number of vegetation array properties                 !
!  CD_VEG        Drag coefficient for each veg type                    ! 
!  E_VEG         Youngs modulus for each veg type                      !
!  VEG_MASSDEN   Mass density for each veg type                        !
!  VEGHMIXCOEF   Viscosity coefficient for vegetation boundary         ! 
!                                                                      ! 
!  Plant Property indices:                                             !
!  ======================                                              !
!  pdens         Density                                               !
!  phght         Height                                                !
!  pdiam         Diameter                                              !
!  pthck         Thickness                                             !
!  pabbm         Above ground biomass                                  !
!  pbgbm         Below ground biomass                                  !
!                                                                      !
!  Plant Property indices:                                             !
!  ======================                                              !
!  idvprp        Indices for storing plant properties                  ! 
!                                                                      !
!  Plant Property Output IDs:                                          !
!  ==========================                                          !
!  ipdens         Id to output plant density                           !
!  iphght         Id to output plant height                            !
!  ipdiam         Id to output plant diameter                          !
!  ipthck         Id to output plant thickness                         !
!  ipupbm         Id to output above ground biomass                    !
!  ipdwbm         Id to output below ground biomass                    !
!  idWdvg         Id to output wave dissipation from vegetation        !
!                                                                      !
!  Wave Thrust on Marsh Output:                                        !
!  ==========================                                          !
!  idTims        Initial masking for the marsh                         ! 
!  idTmsk        Reducing masking value due to depth                   ! 
!  idTton        Tonelli thrust from all directions due to waves       !
!=======================================================================
!
      USE mod_param
!
      implicit none
!
#if defined VEG_DRAG || defined VEG_BIOMASS  
      integer :: NVEG, NVEGP
      integer :: counter
      integer :: phght, pdens, pdiam, pthck
      integer :: ipdens,iphght,ipdiam,ipthck
#endif 
#ifdef VEG_BIOMASS 
      integer :: pabbm, pbgbm   
      integer :: ipabbm, ipbgbm   
#endif 
#ifdef VEG_STREAMING 
      integer :: idWdvg
#endif 
      integer, allocatable :: idvprp(:)    
#ifdef MARSH_WAVE_THRUST 
      integer ::  idTims, idTmsk, idTton
#endif 
!
#if defined VEG_DRAG || defined VEG_BIOMASS  
      real(r8), allocatable :: E_VEG(:,:)
      real(r8), allocatable :: CD_VEG(:,:)
      real(r8), allocatable :: VEG_MASSDENS(:,:)
      real(r8), allocatable :: VEGHMIXCOEF(:,:)
#endif 
#if defined MARSH_SED_BEDLOAD 
      real(r8), allocatable :: KFAC_MARSH(:)
      real(r8), allocatable :: DCRIT_MARSH(:)
#endif 
!
      CONTAINS 
! 
      SUBROUTINE initialize_vegetation
!
      USE mod_param
!
      implicit none 
!
!     Setup property indices 
!
#if defined VEG_DRAG || defined VEG_BIOMASS  
       counter = 1
       pdens   = counter 
       counter = counter+1 
       phght   = counter
       counter = counter+1 
       pdiam   = counter
       counter = counter+1 
       pthck   = counter
#endif 
#ifdef VEG_BIOMASS 
       counter = counter+1 
       pabbm   = counter
       counter = counter+1 
       pbgbm   = counter 
#endif 
#if defined VEG_DRAG || defined VEG_BIOMASS  
       NVEGP = counter
       IF (.not.allocated(idvprp)) THEN
         allocate ( idvprp(NVEGP) )
       END IF
#endif 
      RETURN
      END SUBROUTINE initialize_vegetation
