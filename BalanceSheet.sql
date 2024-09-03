drop procedure if Exists PROC_BALANCE_SHEET;
DELIMITER $$
CREATE PROCEDURE `PROC_BALANCE_SHEET`( P_ENTRY_DATE_FROM TEXT,
					P_ENTRY_DATE_TO TEXT,
					P_YEAR TEXT,
					P_COMPANY_ID INT )
BEGIN

				Declare IncomeAmount		Decimal(22,2) default 0;
				Declare CostAmount    		Decimal(22,2) default 0;
				Declare ExpenseAmount 		Decimal(22,2) default 0;
				Declare AssetAmount   		Decimal(22,2) default 0;
				Declare LiabilityAmount 	Decimal(22,2) default 0;
				Declare EquityAmount 		Decimal(22,2) default 0;
				Declare GrossProfit 		Decimal(22,2) default 0;
				Declare EquityType          Decimal(22,2) default 0;
				Declare TOTAL_L_E			Decimal(22,2) Default 0;
			
				select 
						SUM(A.Income)   ,
						SUM(A.Cost)     ,
						Sum(A.Expense)  ,
						Sum(A.Asset)    ,
						SUM(A.Liability),
						Sum(A.Equity)
				into 
						IncomeAmount,
						CostAmount,
						ExpenseAmount,
						AssetAmount,
						LiabilityAmount,
						EquityAmount
				from (
						select 
								Case when A.Account_ID = 1 then A.Balance else 0 end as Income,
								Case When A.Account_ID = 2 then A.Balance else 0 end as Cost,
								Case When A.Account_Id = 5 then A.Balance else 0 end as Expense,
								Case When A.Account_Id = 3 then A.Balance else 0 end as Asset,
								Case When A.Account_Id = 4 then A.Balance else 0 end as Liability,
								Case when A.Account_Id = 6 then A.Balance else 0 end as Equity
						from (
									select 
											SUM(A.Balance) as Balance ,
											A.AccountId,
											B.ACC_ID,
											D.Accounts_Name,
											C.Account_Id 
									from 
											Daily_Account_Balance A 
									inner join 
											Accounts_Id B 
									on 
											A.AccountId = B.id	
									inner join 
											Account_Type C 
									ON 
											B.Account_Type_Id = C.id	
									inner join 
											Accounts D 
									on 
											C.Account_Id = D.id
									where 
											case 
												when 
													P_ENTRY_DATE_TO <> "" then 
													A.ENTRYDATE <= DATE(P_ENTRY_DATE_TO)
													else true
											end
									and 
											case 
												when 
													P_COMPANY_ID <> "" then 
													B.Company_Id = P_COMPANY_ID
													else true
											end
									group by 
											A.AccountId,
											B.ACC_ID,
											D.Accounts_Name,
											C.Account_Id 
									order by
											C.Account_Id
							 ) as A 
					) as A;
					
					
					-- ===================== TOTAL GROSS =====================
                  
					SELECT IFNULL(IncomeAmount, 0) - IFNULL(CostAmount, 0) - IFNULL(ExpenseAmount, 0) INTO GrossProfit;
                  
					-- ===================== TOTAL GROSS =====================
					
					
					-- ===================== EQUITY TYPE =====================
                  
					SELECT 
							E.ID 
					INTO 
							EquityType
					FROM 
							Accounts_Id D,
						    Account_Type E
					WHERE 
						   CASE
							WHEN P_COMPANY_ID <> "" THEN D.COMPANY_ID = P_COMPANY_ID
							ELSE TRUE
						   END 
					AND D.Account_Type_Id = E.Id
					AND E.Account_Id = 6 
    				ORDER BY E.Id DESC LIMIT 1;
                  
					-- ===================== EQUITY TYPE =====================
					
					-- ===================== TOTAL LIABILITY AND EQUITY =====================
                  
					SELECT IFNULL(LiabilityAmount, 0) + IFNULL(EquityAmount, 0) + IFNULL(GrossProfit, 0) INTO TOTAL_L_E;

					-- ===================== TOTAL LIABILITY AND EQUITY =====================
					
                    select *,COUNT(*) OVER() AS TOTAL_ROWS 
					from (
							select 
								  distinct 
								  V.Account,
								  V.Account_Type,
								  V.ID,
								  V.ACC_ID,
								  V.DESCRIPTION,
								  V.AMOUNT
								  
							from (
							SELECT 
									  ACCOUNT,
									  ACCOUNT_TYPE, 
									  ID,
									  ACC_ID, 
									  DESCRIPTION, 
									  Round(cast(AMOUNT as Decimal(22,2)),2) AS AMOUNT
									  
							from (
							SELECT 
									G.SortingOrder,
									G.ACCOUNT,
									G.ACCOUNT_TYPE_ID,
									G.ACCOUNT_TYPE, 
									G.ID,
									G.ACC_ID, 
									G.DESCRIPTION, 
									SUM(G.AMOUNT) AS AMOUNT
									
							from (
								
								select * from (
							   
									SELECT 
											G.ACCOUNT,
											G.ACCOUNT_TYPE_ID,
											G.ACCOUNT_TYPE, 
											G.ID,
											G.ACC_ID, 
											G.DESCRIPTION, 
											G.AMOUNT AS AMOUNT,
											case 
												when G.Account  = "Equity" 	  then 'c'
												when G.Account  = "Liabilities" then 'b'
												when G.Account = "-1" then 'd'
												Else 'a'
											END as SortingOrder
									from 
										(
			
												select 
														
														D.Accounts_Name 		as Account,
														C.id 					as Account_Type_Id,
														C.Account_Type_Name 	as Account_Type,
														B.id,
														B.ACC_ID,
														B.Description,
														SUM(A.Balance) 			as Amount
														
												from 
														Daily_Account_Balance A 
												Right join 
														Accounts_Id B 
												on 
														B.id = A.AccountId
												inner join 
														Account_Type C 
												ON 
														C.id = B.Account_Type_Id 
												inner join 
														Accounts D  
												ON 
														D.id = C.Account_Id
												where 
														case 
															when 
																P_COMPANY_ID <> "" then B.COMPANY_ID = P_COMPANY_ID
																else true 
															end 
												And 
														case 
															when 
																P_ENTRY_DATE_TO <> "" then A.ENTRYDATE <= DATE(P_ENTRY_DATE_TO)
																else true 
															end 
												AND 
														(D.id =3 OR D.id = 4 OR D.id = 6)
												group by 
														D.Accounts_Name,
														C.id,
														C.Account_Type_Name,
														B.id,
														B.ACC_ID,
														B.Description
									
														UNION ALL
																			
														SELECT 
																"Equity" 					AS ACCOUNT,
																 EquityType 				AS ACCOUNT_TYPE_ID,
																"Equity" 					AS ACCOUNT_TYPE,
																"-1"						AS ID,
																"-1" 						AS ACC_ID,
																case when GrossProfit >0 then "NET PROFIT"  else "NET LOSS" END	AS DESCRIPTION,
																Round(cast(IFNULL(GrossProfit,0) as Decimal(22,2)),2)		AS AMOUNT
										)G
										
										)G order by G.SortingOrder asc
										
										) G
							group by 
									G.SortingOrder,
									G.ACCOUNT,
									G.ACCOUNT_TYPE_ID,
									G.ACCOUNT_TYPE, 
									G.ID,
									G.ACC_ID, 
									G.DESCRIPTION
							with RollUp
							HAVING 
									(
									  G.SortingOrder is not null And
									  G.Account      is not null And
									  G.Account_Type_ID is not null And 
									  G.ACCOUNT_TYPE is not null And  
									  G.ID           is not null And
									  G.ACC_ID       is not null And 
									  G.DESCRIPTION  is not null And 
									  AMOUNT       is not null
										
									)
							OR 		
									(
									  G.SortingOrder is not null And
									  G.Account      is not null And
									  G.ACCOUNT_TYPE_ID is not null And
									  G.Account_TYPE is  null    AND 
									  G.ID           is  null And
									  G.ACC_ID       is  null And 
									  G.DESCRIPTION  is  null And 
									  AMOUNT       is not null
										
									)
								OR 		
									(
									  G.SortingOrder is not null And
									  G.Account      is not null And
									  G.ACCOUNT_TYPE_ID is null And
									  G.Account_TYPE is  null    AND 
									  G.ID           is  null And
									  G.ACC_ID       is  null And 
									  G.DESCRIPTION  is  null And 
									  AMOUNT       is not null
										
									)
							
									
									union all 
							
									SELECT 
									'Z'    As SortingOrder,
										"" AS ACCOUNT,
								"99999999" AS ACCOUNT_TYPE_ID,
								"99999999" AS ACCOUNT_TYPE,
										"" AS ID,
										"" AS ACC_ID,
			  "Total Liability and Equity" AS ACCOUNT,
					  Round(cast(IFNULL(TOTAL_L_E,0) as Decimal(22,2)),2) AS AMOUNT
							   ) as V
							   )V
					    )C;
					
					
	
	
    
END $$
DELIMITER ;
